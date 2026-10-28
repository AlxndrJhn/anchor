import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsNotEmpty,
  IsString,
} from 'class-validator';
import { BULK_MAX_NOTE_IDS } from '../constants/notes.constants';

export class NoteInvisibleDto {
  // true keeps the note out of this person's lists (search still finds it);
  // false shows it again.
  @IsBoolean()
  isInvisible: boolean;
}

export class BulkInvisibleDto extends NoteInvisibleDto {
  @IsArray()
  @ArrayMaxSize(BULK_MAX_NOTE_IDS)
  @IsString({ each: true })
  @IsNotEmpty({ each: true })
  noteIds: string[];
}
