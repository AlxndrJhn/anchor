import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsNotEmpty,
  IsString,
} from 'class-validator';
import { BULK_MAX_NOTE_IDS } from '../constants/notes.constants';

export class NoteFreezeDto {
  // true freezes the note; false lets it be changed and deleted again.
  @IsBoolean()
  isFrozen: boolean;
}

export class BulkFreezeDto extends NoteFreezeDto {
  @IsArray()
  @ArrayMaxSize(BULK_MAX_NOTE_IDS)
  @IsString({ each: true })
  @IsNotEmpty({ each: true })
  noteIds: string[];
}
