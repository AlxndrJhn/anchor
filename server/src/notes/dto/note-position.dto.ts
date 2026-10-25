import { IsNumber, ValidateIf } from 'class-validator';

export class NotePositionDto {
  // Higher sorts first; null forgets the place, back to when it was made.
  @ValidateIf((_, value) => value !== null)
  @IsNumber({ allowNaN: false, allowInfinity: false })
  position: number | null;
}
