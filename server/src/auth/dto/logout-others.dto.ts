import { IsNotEmpty, IsString } from 'class-validator';

export class LogoutOthersDto {
  // The session that asked, kept signed in; every other one is signed out.
  @IsNotEmpty()
  @IsString()
  refreshToken: string;
}
