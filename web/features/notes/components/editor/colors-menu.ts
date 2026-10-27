import { create } from "zustand";

/** Whether a colour menu is open; the selection bubble steps aside then. */
export const useColorsMenu = create<{ isOpen: boolean }>(() => ({
  isOpen: false,
}));
