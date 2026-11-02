import { IsEmail, IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class LoginDto {
  @IsEmail()
  email: string;

  @IsNotEmpty()
  password: string;

  // From the authenticator app, or a recovery code, once two-step is on.
  @IsOptional()
  @IsString()
  code?: string;
}
