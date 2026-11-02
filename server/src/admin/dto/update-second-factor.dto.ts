import { IsBoolean } from 'class-validator';
import { RejectUnknownFields } from '../../common/decorators/reject-unknown-fields.decorator';

@RejectUnknownFields()
export class UpdateSecondFactorDto {
  @IsBoolean()
  required!: boolean;
}
