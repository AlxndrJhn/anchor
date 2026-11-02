import { IsString, MaxLength } from 'class-validator';
import { RejectUnknownFields } from '../../common/decorators/reject-unknown-fields.decorator';

@RejectUnknownFields()
export class TestOidcIssuerDto {
  @IsString()
  @MaxLength(2048)
  issuerUrl!: string;
}
