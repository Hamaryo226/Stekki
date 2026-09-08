import { requireOptionalNativeModule } from 'expo';

export interface Book {
  id: string;
  title: string;
  color: string;
  pageCount: number;
  stickerCount: number;
}

interface StekkiNative {
  listBooks(): Promise<Book[]>;
  createBook(title: string): Promise<string>;
  renameBook(id: string, title: string): Promise<void>;
  deleteBook(id: string): Promise<void>;
  openBook(id: string): Promise<void>;
  createSticker(kind: 'photo' | 'text'): Promise<void>;
  receiveFile(uri: string): Promise<void>;
}

// Expo Go / other platforms show an explicit explanation, never an empty fake store.
export const native = requireOptionalNativeModule<StekkiNative>('StekkiNative');
