import { IsObject } from 'class-validator';
import { RejectUnknownFields } from '../../common/decorators/reject-unknown-fields.decorator';

/** An addon to install: addon.json and its files; see addon-manifest.ts. */
@RejectUnknownFields()
export class InstallAddonDto {
  @IsObject()
  manifest: Record<string, unknown>;

  @IsObject()
  files: Record<string, unknown>;
}
