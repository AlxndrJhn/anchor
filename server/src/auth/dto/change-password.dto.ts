import { IsNotEmpty, IsOptional, IsString, MinLength } from 'class-validator';

export class ChangePasswordDto {
  @IsNotEmpty()
  currentPassword: string;

  @IsNotEmpty()
  @MinLength(8)
  newPassword: string;

  // The session that changed the password, kept signed in; every other one
  // is signed out.
  @IsOptional()
  @IsString()
  refreshToken?: string;
}
