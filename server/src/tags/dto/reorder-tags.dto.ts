import { ArrayMaxSize, IsArray, IsString } from 'class-validator';

export class ReorderTagsDto {
  /** All the person's tags, in the order they want them. */
  @IsArray()
  @ArrayMaxSize(10_000)
  @IsString({ each: true })
  ids: string[];
}
