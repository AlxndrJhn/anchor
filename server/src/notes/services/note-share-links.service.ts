import { randomBytes } from 'crypto';
import {
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { NoteSharePermission, NoteState } from 'src/generated/prisma/enums';
import type { Note, NoteShareLink } from 'src/generated/prisma/client';
import { NoteAccessService } from './note-access.service';
import { NoteAttachmentsService } from './note-attachments.service';
import {
  SyncEmitterService,
  noteEmissions,
} from '../../sync/sync-emitter.service';
import { NoteRevisionsService } from '../../sync/note-revisions.service';
import { noteContentChanged } from '../utils/note-versioning.util';
import { ERROR_MESSAGES } from '../constants/notes.constants';
import { UpdateLinkedNoteDto } from '../dto/note-share-link.dto';

// 256 bits: a link can't be guessed, only passed on.
const TOKEN_BYTES = 32;

const toLinkResponse = (link: NoteShareLink) => ({
  token: link.token,
  permission: link.permission,
  createdAt: link.createdAt.toISOString(),
  updatedAt: link.updatedAt.toISOString(),
});

/**
 * Share links: anyone with a note's link opens it without an account, to read
 * it or, with an editing link, to change its title and text.
 */
@Injectable()
export class NoteShareLinksService {
  constructor(
    private prisma: PrismaService,
    private noteAccessService: NoteAccessService,
    private noteAttachmentsService: NoteAttachmentsService,
    private syncEmitter: SyncEmitterService,
    private noteRevisions: NoteRevisionsService,
  ) {}

  async getLink(ownerId: string, noteId: string) {
    await this.noteAccessService.verifyNoteOwnership(ownerId, noteId);
    const link = await this.prisma.noteShareLink.findUnique({
      where: { noteId },
    });
    return { link: link ? toLinkResponse(link) : null };
  }

  /** Makes the note's link, or changes what it lets people do. */
  async setLink(
    ownerId: string,
    noteId: string,
    permission: NoteSharePermission,
  ) {
    await this.noteAccessService.verifyNoteOwnership(ownerId, noteId);
    const link = await this.prisma.noteShareLink.upsert({
      where: { noteId },
      create: {
        noteId,
        permission,
        token: randomBytes(TOKEN_BYTES).toString('base64url'),
      },
      update: { permission },
    });
    return { link: toLinkResponse(link) };
  }

  /** The link stops working; a new one gets a new token. */
  async removeLink(ownerId: string, noteId: string) {
    await this.noteAccessService.verifyNoteOwnership(ownerId, noteId);
    await this.prisma.noteShareLink.deleteMany({ where: { noteId } });
    return { success: true };
  }

  async openLink(token: string) {
    const { link, note } = await this.findLinkedNote(token);
    return this.toLinkedNote(link, note);
  }

  async updateLinkedNote(token: string, dto: UpdateLinkedNoteDto) {
    const { link } = await this.findLinkedNote(token);
    if (link.permission !== NoteSharePermission.editor) {
      throw new ForbiddenException(ERROR_MESSAGES.SHARE_LINK_VIEW_ONLY);
    }
    const { baseVersion, ...noteData } = dto;
    const noteId = link.noteId;

    const outcome = await this.prisma.$transaction(async (tx) => {
      const prior = await tx.note.findUniqueOrThrow({ where: { id: noteId } });
      if (prior.state !== NoteState.active) {
        return { gone: true as const };
      }
      if (!noteContentChanged(prior, noteData)) {
        return { note: prior };
      }
      if (prior.isFrozen) {
        return { frozen: true as const };
      }
      if (baseVersion !== undefined && baseVersion !== prior.version) {
        return { conflict: true as const };
      }

      // A writer that slipped in since the read above makes count 0.
      const updated = await tx.note.updateMany({
        where: { id: noteId, version: prior.version },
        data: { ...noteData, version: { increment: 1 } },
      });
      if (updated.count !== 1) {
        return { conflict: true as const };
      }
      await this.noteRevisions.recordEdit(tx, prior, null);

      const recipients = await this.syncEmitter.noteRecipients(tx, noteId);
      await this.syncEmitter.emit(tx, noteEmissions(recipients, noteId));

      return {
        note: await tx.note.findUniqueOrThrow({ where: { id: noteId } }),
      };
    });

    if ('gone' in outcome) {
      throw new NotFoundException(ERROR_MESSAGES.SHARE_LINK_NOT_FOUND);
    }
    if ('frozen' in outcome) {
      throw new ForbiddenException(ERROR_MESSAGES.NOTE_FROZEN);
    }
    if ('conflict' in outcome) {
      const current = await this.findLinkedNote(token);
      throw new ConflictException({
        message: 'Note was changed by someone else',
        serverNote: await this.toLinkedNote(current.link, current.note),
      });
    }
    return this.toLinkedNote(link, outcome.note);
  }

  async serveLinkedFile(token: string, attachmentId: string) {
    const { link } = await this.findLinkedNote(token);
    return this.noteAttachmentsService.serveFileForLink(
      link.noteId,
      attachmentId,
    );
  }

  // Only an active note opens: in the trash, the link stops working until
  // the note is restored.
  private async findLinkedNote(token: string) {
    const link = await this.prisma.noteShareLink.findUnique({
      where: { token },
      include: { note: true },
    });
    if (!link || link.note.state !== NoteState.active) {
      throw new NotFoundException(ERROR_MESSAGES.SHARE_LINK_NOT_FOUND);
    }
    const { note, ...rest } = link;
    return { link: rest, note };
  }

  // Nothing about the owner or the people it's shared with: only the note.
  private async toLinkedNote(link: NoteShareLink, note: Note) {
    const attachments = await this.noteAttachmentsService.listForLink(note.id);
    return {
      title: note.title,
      content: note.content,
      background: note.background,
      version: note.version,
      updatedAt: note.updatedAt.toISOString(),
      isFrozen: note.isFrozen,
      permission: link.permission,
      canEdit: link.permission === NoteSharePermission.editor && !note.isFrozen,
      attachments: attachments.map((attachment) => ({
        id: attachment.id,
        type: attachment.type,
        originalFilename: attachment.originalFilename,
        mimeType: attachment.mimeType,
        fileSize: attachment.fileSize,
        position: attachment.position,
      })),
    };
  }
}
