// Generated from design/schemes/schemes.json by design/build/schemes.mjs. Do not edit by hand.

export interface SchemeSwatch {
  background: string;
  card: string;
  foreground: string;
  accent: string;
}

export interface ColorScheme {
  id: string;
  name: string;
  light: SchemeSwatch;
  dark: SchemeSwatch;
}

export const COLOR_SCHEMES: ColorScheme[] = [
  {
    id: "nord",
    name: "Nord",
    light: { background: "#ECEFF4", card: "#F8F9FB", foreground: "#2E3440", accent: "#5E81AC" },
    dark: { background: "#2E3440", card: "#3B4252", foreground: "#ECEFF4", accent: "#88C0D0" },
  },
  {
    id: "dracula",
    name: "Dracula",
    light: { background: "#FFFBEB", card: "#FFFFFF", foreground: "#1F1F1F", accent: "#644AC9" },
    dark: { background: "#282A36", card: "#343746", foreground: "#F8F8F2", accent: "#BD93F9" },
  },
  {
    id: "solarized",
    name: "Solarized",
    light: { background: "#FDF6E3", card: "#FFFBEF", foreground: "#073642", accent: "#268BD2" },
    dark: { background: "#002B36", card: "#073642", foreground: "#EEE8D5", accent: "#268BD2" },
  },
  {
    id: "gruvbox",
    name: "Gruvbox",
    light: { background: "#FBF1C7", card: "#F9F5D7", foreground: "#3C3836", accent: "#AF3A03" },
    dark: { background: "#282828", card: "#3C3836", foreground: "#EBDBB2", accent: "#FE8019" },
  },
  {
    id: "catppuccin",
    name: "Catppuccin",
    light: { background: "#EFF1F5", card: "#F8F9FB", foreground: "#4C4F69", accent: "#8839EF" },
    dark: { background: "#1E1E2E", card: "#2A2B3C", foreground: "#CDD6F4", accent: "#CBA6F7" },
  },
  {
    id: "tokyo-night",
    name: "Tokyo Night",
    light: { background: "#E1E2E7", card: "#EDEEF2", foreground: "#343B58", accent: "#2E7DE9" },
    dark: { background: "#1A1B26", card: "#24283B", foreground: "#C0CAF5", accent: "#7AA2F7" },
  },
  {
    id: "one",
    name: "One",
    light: { background: "#FAFAFA", card: "#FFFFFF", foreground: "#383A42", accent: "#4078F2" },
    dark: { background: "#282C34", card: "#2F333D", foreground: "#D7DAE0", accent: "#61AFEF" },
  },
  {
    id: "rose-pine",
    name: "Rosé Pine",
    light: { background: "#FAF4ED", card: "#FFFAF3", foreground: "#575279", accent: "#D7827E" },
    dark: { background: "#191724", card: "#1F1D2E", foreground: "#E0DEF4", accent: "#EBBCBA" },
  },
  {
    id: "monokai",
    name: "Monokai",
    light: { background: "#FAF4F2", card: "#FFFFFF", foreground: "#29242A", accent: "#269D69" },
    dark: { background: "#272822", card: "#3E3D32", foreground: "#F8F8F2", accent: "#A6E22E" },
  },
  {
    id: "github",
    name: "GitHub",
    light: { background: "#F6F8FA", card: "#FFFFFF", foreground: "#1F2328", accent: "#0969DA" },
    dark: { background: "#0D1117", card: "#151B23", foreground: "#F0F6FC", accent: "#4493F8" },
  },
];
