import {
  ConflictException,
  HttpException,
  HttpStatus,
  Injectable,
} from '@nestjs/common';
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import type { CallToolResult } from '@modelcontextprotocol/sdk/types.js';
import { z } from 'zod';
import { NotesService } from '../notes/services/notes.service';
import { TagsService } from '../tags/tags.service';
import type { TransformedNote } from '../notes/utils/note-transformer.util';
import {
  appendMarkdownToContent,
  markdownCanCarry,
  markdownToNoteContent,
  noteContentToMarkdown,
} from './note-markdown.util';

const SNIPPET_LENGTH = 200;
const DEFAULT_LIMIT = 50;
const MAX_LIMIT = 200;

type Tag = { id: string; name: string };

const INSTRUCTIONS =
  "Anchor is the user's note taking app. Notes have a title and a body, " +
  'which these tools read and write as markdown: headings, lists, ' +
  'checklists ("- [ ] item", "- [x] done"), bold, italic, ~~strike~~, ' +
  '<u>underline</u>, ==highlight==, links, quotes and code blocks. ' +
  'Read a note with get_note before changing it. Locked notes keep their ' +
  'text to themselves, and frozen notes cannot be changed.';

/** Builds the MCP server Claude talks to, acting as one Anchor user. */
@Injectable()
export class AnchorMcpService {
  constructor(
    private readonly notesService: NotesService,
    private readonly tagsService: TagsService,
  ) {}

  createServer(userId: string): McpServer {
    const server = new McpServer(
      { name: 'anchor', version: '1.0.0' },
      { instructions: INSTRUCTIONS },
    );

    server.registerTool(
      'list_notes',
      {
        title: 'List notes',
        description:
          'Lists notes, newest first, with a snippet of each. Searches ' +
          'titles, text and the text in pictures when a query is given; ' +
          'invisible notes only show up in a search.',
        inputSchema: {
          query: z.string().optional().describe('Text to search for'),
          tag: z.string().optional().describe('Only notes with this tag'),
          scope: z
            .enum(['notes', 'archive', 'trash'])
            .default('notes')
            .describe('Which notes to list'),
          limit: z.number().int().min(1).max(MAX_LIMIT).default(DEFAULT_LIMIT),
        },
        annotations: { readOnlyHint: true },
      },
      ({ query, tag, scope, limit }) =>
        this.run(async () => {
          const tags = await this.tags(userId);
          let tagId: string | undefined;
          if (tag) {
            tagId = findTag(tags, tag)?.id;
            if (!tagId) return `No tag is called "${tag}".`;
          }

          let notes: TransformedNote[];
          if (scope === 'notes') {
            notes = await this.notesService.findAll(
              userId,
              query,
              tagId,
              query ? limit : undefined,
            );
            if (!query) notes = notes.filter((note) => !note.isInvisible);
          } else {
            notes =
              scope === 'archive'
                ? await this.notesService.findArchived(userId)
                : await this.notesService.findTrashed(userId);
            if (tagId) notes = notes.filter((n) => n.tagIds.includes(tagId));
            if (query) notes = notes.filter((n) => matches(n, query));
          }

          const page = notes.slice(0, limit);
          return {
            notes: page.map((note) => summarize(note, tags)),
            ...(notes.length > page.length
              ? { more: notes.length - page.length }
              : {}),
          };
        }),
    );

    server.registerTool(
      'get_note',
      {
        title: 'Read a note',
        description:
          'Reads a note: its title, its text as markdown, its tags and ' +
          'its version, which update_note takes to avoid overwriting edits.',
        inputSchema: { id: z.string().describe('The note id') },
        annotations: { readOnlyHint: true },
      },
      ({ id }) =>
        this.run(async () => {
          const note = await this.notesService.findOne(userId, id);
          return describe(note, await this.tags(userId));
        }),
    );

    server.registerTool(
      'list_tags',
      {
        title: 'List tags',
        description: 'Lists the tags, with how many notes have each.',
        annotations: { readOnlyHint: true },
      },
      () =>
        this.run(async () => {
          const tags = await this.tagsService.findAll(userId);
          return tags.map((tag) => ({
            id: tag.id,
            name: tag.name,
            notes: tag._count.notes,
          }));
        }),
    );

    server.registerTool(
      'create_note',
      {
        title: 'Create a note',
        description: 'Creates a note. Tags that do not exist yet are created.',
        inputSchema: {
          title: z.string().default(''),
          content: z.string().default('').describe('The text, as markdown'),
          tags: z.array(z.string()).optional().describe('Tag names'),
          pinned: z.boolean().optional(),
        },
      },
      ({ title, content, tags, pinned }) =>
        this.run(async () => {
          const note = await this.notesService.create(userId, {
            title,
            content: markdownToNoteContent(content),
            isPinned: pinned,
            tagIds: tags ? await this.tagIds(userId, tags) : undefined,
          });
          return describe(note, await this.tags(userId));
        }),
    );

    server.registerTool(
      'update_note',
      {
        title: 'Change a note',
        description:
          'Changes a note. Leave out what stays as it is. content replaces ' +
          'the whole text, so pass the full markdown; to add lines at the ' +
          'end, use append_to_note. tags replaces the tag list.',
        inputSchema: {
          id: z.string(),
          version: z
            .number()
            .int()
            .optional()
            .describe('The version get_note returned; refused if it changed'),
          title: z.string().optional(),
          content: z.string().optional().describe('The new text, as markdown'),
          tags: z.array(z.string()).optional().describe('Tag names'),
          pinned: z.boolean().optional(),
          archived: z.boolean().optional(),
        },
      },
      ({ id, version, title, content, tags, pinned, archived }) =>
        this.run(async () => {
          const current = await this.notesService.findOne(userId, id);
          if (content !== undefined) {
            if (current.lock) throw locked();
            if (!markdownCanCarry(current.content)) {
              throw new HttpException(
                'This note has pictures in its text, colours, fonts or ' +
                  'highlights that markdown cannot carry, so its text ' +
                  'cannot be replaced. Use append_to_note, or change it in ' +
                  'Anchor.',
                HttpStatus.UNPROCESSABLE_ENTITY,
              );
            }
          }
          const note = await this.notesService.update(userId, id, {
            title,
            content:
              content === undefined
                ? undefined
                : markdownToNoteContent(content),
            isPinned: pinned,
            isArchived: archived,
            tagIds: tags ? await this.tagIds(userId, tags) : undefined,
            baseVersion: version ?? current.version,
          });
          return describe(note, await this.tags(userId));
        }),
    );

    server.registerTool(
      'append_to_note',
      {
        title: 'Add to a note',
        description:
          'Adds markdown lines to the end of a note, keeping everything ' +
          'already in it, such as items for a checklist ("- [ ] eggs").',
        inputSchema: {
          id: z.string(),
          content: z.string().describe('The lines to add, as markdown'),
        },
      },
      ({ id, content }) =>
        this.run(async () => {
          const current = await this.notesService.findOne(userId, id);
          if (current.lock) throw locked();
          const note = await this.notesService.update(userId, id, {
            content: appendMarkdownToContent(current.content, content),
            baseVersion: current.version,
          });
          return describe(note, await this.tags(userId));
        }),
    );

    server.registerTool(
      'trash_note',
      {
        title: 'Move a note to the trash',
        description:
          'Moves a note to the trash, where it can be restored from in ' +
          'Anchor until the trash is emptied.',
        inputSchema: { id: z.string() },
        annotations: { destructiveHint: true },
      },
      ({ id }) =>
        this.run(async () => {
          await this.notesService.remove(userId, id);
          return `Moved note ${id} to the trash.`;
        }),
    );

    return server;
  }

  private async tags(userId: string): Promise<Tag[]> {
    return this.tagsService.findAll(userId);
  }

  /** Ids for tag names, creating the ones that don't exist. */
  private async tagIds(userId: string, names: string[]): Promise<string[]> {
    const tags = await this.tags(userId);
    const ids: string[] = [];
    for (const raw of names) {
      const name = raw.trim();
      if (!name) continue;
      const tag =
        findTag(tags, name) ??
        (await this.tagsService.create(userId, { name }));
      tags.push(tag);
      if (!ids.includes(tag.id)) ids.push(tag.id);
    }
    return ids;
  }

  /** Runs a tool, turning what it returns or throws into its result. */
  private async run(
    tool: () => Promise<string | object>,
  ): Promise<CallToolResult> {
    try {
      const result = await tool();
      return {
        content: [
          {
            type: 'text',
            text:
              typeof result === 'string'
                ? result
                : JSON.stringify(result, null, 2),
          },
        ],
      };
    } catch (error) {
      return {
        isError: true,
        content: [{ type: 'text', text: errorMessage(error) }],
      };
    }
  }
}

function findTag(tags: Tag[], name: string): Tag | undefined {
  const wanted = name.trim().toLowerCase();
  return tags.find((tag) => tag.name.toLowerCase() === wanted);
}

function tagNames(note: TransformedNote, tags: Tag[]): string[] {
  return note.tagIds.flatMap((id) => {
    const tag = tags.find((t) => t.id === id);
    return tag ? [tag.name] : [];
  });
}

function matches(note: TransformedNote, query: string): boolean {
  const wanted = query.toLowerCase();
  return [note.title, note.lock ? '' : note.content, note.pictureText].some(
    (text) => text?.toLowerCase().includes(wanted),
  );
}

function flags(note: TransformedNote) {
  return {
    ...(note.isPinned ? { pinned: true } : {}),
    ...(note.isArchived ? { archived: true } : {}),
    ...(note.state === 'trashed' ? { trashed: true } : {}),
    ...(note.isFrozen ? { frozen: true } : {}),
    ...(note.lock ? { locked: true } : {}),
    ...(note.permission !== 'owner' ? { sharedWithYou: note.permission } : {}),
  };
}

function summarize(note: TransformedNote, tags: Tag[]) {
  const text = note.lock ? '' : noteContentToMarkdown(note.content);
  return {
    id: note.id,
    title: note.title,
    snippet:
      text.length > SNIPPET_LENGTH
        ? `${text.slice(0, SNIPPET_LENGTH).trimEnd()}…`
        : text.trimEnd(),
    tags: tagNames(note, tags),
    updatedAt: note.updatedAt,
    ...flags(note),
  };
}

function describe(note: TransformedNote, tags: Tag[]) {
  return {
    id: note.id,
    title: note.title,
    version: note.version,
    tags: tagNames(note, tags),
    createdAt: note.createdAt,
    updatedAt: note.updatedAt,
    ...flags(note),
    ...(note.attachmentCount ? { attachments: note.attachmentCount } : {}),
    content: note.lock ? null : noteContentToMarkdown(note.content),
    ...(note.lock
      ? { note: 'This note is locked; unlock it in Anchor to read it.' }
      : {}),
  };
}

function locked(): HttpException {
  return new HttpException(
    'This note is locked; unlock it in Anchor to change its text.',
    HttpStatus.FORBIDDEN,
  );
}

function errorMessage(error: unknown): string {
  if (error instanceof ConflictException) {
    return `${error.message}. Read it again and retry.`;
  }
  return error instanceof Error ? error.message : String(error);
}
