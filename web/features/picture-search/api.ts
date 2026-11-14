import { api } from "@/lib/api/client";

/** Where the picture search model is. */
export type PictureModelState =
  | { state: "absent" }
  | { state: "downloading"; progress: number }
  | { state: "ready" }
  | { state: "failed"; error: string };

export interface PictureSearchStatus {
  /** Whether the server offers it at all. */
  available: boolean;
  /** Whether it's on for this user. */
  enabled: boolean;
  model: PictureModelState;
  /** The user's pictures done, of all of them. */
  indexed: number;
  total: number;
}

export interface PictureMatch {
  noteId: string;
  attachmentId: string;
  score: number;
}

export const pictureSearchStatusKey = ["picture-search", "status"];

export function getPictureSearchStatus() {
  return api.get("api/picture-search/status").json<PictureSearchStatus>();
}

export function setPictureSearch(enabled: boolean) {
  return api
    .put("api/picture-search/settings", { json: { enabled } })
    .json<PictureSearchStatus>();
}

/** Notes whose pictures look like the description, best first. */
export async function searchPictures(q: string): Promise<PictureMatch[]> {
  const { results } = await api
    .get("api/picture-search", { searchParams: { q } })
    .json<{ results: PictureMatch[] }>();
  return results;
}

/** A word for what a picture shows. */
export interface PictureLabel {
  en: string;
  /** In the language asked for, else English; missing from older servers. */
  text?: string;
  score: number;
}

/**
 * What a picture shows, best first ("Show detected tags"), in `language`
 * (a tag such as "fr" or "pt-BR") when the words come in it, else English.
 */
export async function getPictureLabels(
  attachmentId: string,
  language: string,
): Promise<PictureLabel[]> {
  const { labels } = await api
    .get(`api/picture-search/attachments/${attachmentId}/labels`, {
      searchParams: { lang: language },
    })
    .json<{ labels: PictureLabel[] }>();
  return labels;
}
