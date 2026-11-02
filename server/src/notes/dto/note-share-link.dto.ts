import { IsEnum, IsInt, IsOptional, IsString, Min } from 'class-validator';
import { NoteSharePermission } from 'src/generated/prisma/enums';

export class SetNoteShareLinkDto {
  @IsEnum(NoteSharePermission)
  permission: NoteSharePermission;
}

/** What someone with an editing link can change: the title and the text. */
export class UpdateLinkedNoteDto {
  @IsString()
  @IsOptional()
  title?: string;

  @IsString()
  @IsOptional()
  content?: string;

  // Version the edit was based on. Stale → 409 with the note as it is now.
  @IsInt()
  @Min(1)
  @IsOptional()
  baseVersion?: number;
}
