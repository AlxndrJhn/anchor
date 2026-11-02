import { Type } from 'class-transformer';
import {
  IsIn,
  IsNotEmpty,
  IsObject,
  IsOptional,
  IsString,
  MaxLength,
  ValidateNested,
} from 'class-validator';

export const LIVE_SIGNAL_KINDS = [
  'want',
  'offer',
  'answer',
  'ice',
  'ready',
  'unavailable',
  'bye',
  'mic',
  'viewers',
] as const;

export type LiveSignalKind = (typeof LIVE_SIGNAL_KINDS)[number];

const ID_MAX_LENGTH = 64;

/** One app on one device: the device keeps its id, each window gets one. */
export class LivePeerDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(ID_MAX_LENGTH)
  device: string;

  @IsOptional()
  @IsString()
  @MaxLength(ID_MAX_LENGTH)
  tab?: string;
}

/**
 * A message between the device showing a live image and one watching it, to
 * set up the video between them. The video itself never passes the server.
 */
export class LiveSignalDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(ID_MAX_LENGTH)
  noteId: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(ID_MAX_LENGTH)
  liveId: string;

  @IsIn(LIVE_SIGNAL_KINDS)
  kind: LiveSignalKind;

  @ValidateNested()
  @Type(() => LivePeerDto)
  from: LivePeerDto;

  /** Missing for messages to every device, e.g. that the video is back. */
  @IsOptional()
  @ValidateNested()
  @Type(() => LivePeerDto)
  to?: LivePeerDto;

  /** Which watcher a connection is with; one per watching window. */
  @IsOptional()
  @IsString()
  @MaxLength(ID_MAX_LENGTH)
  session?: string;

  /** The offer, answer or network candidate, as the browser gives it. */
  @IsOptional()
  @IsObject()
  data?: Record<string, unknown>;
}
