import { env } from "./env";
/** Public-bucket URL (thumbnails, covers, buddies, badge art): served by the Storage CDN. */
export const publicUrl = (path: string | null | undefined) =>
  path ? `${env.url}/storage/v1/object/public/public-assets/${path.split("/").map(encodeURIComponent).join("/")}` : null;
