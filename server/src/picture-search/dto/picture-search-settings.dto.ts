import { IsBoolean } from 'class-validator';

export class PictureSearchSettingsDto {
  @IsBoolean()
  enabled: boolean;
}
