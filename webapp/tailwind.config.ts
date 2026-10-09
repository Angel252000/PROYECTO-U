import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./app/**/*.{ts,tsx}",
    "./components/**/*.{ts,tsx}",
    "./lib/**/*.{ts,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        // Paleta SINAES (semáforo de conformidad)
        conforme: "#639922",
        menor: "#BA7517",
        mayor: "#E24B4A",
        marca: {
          50: "#E6F1FB",
          100: "#B5D4F4",
          500: "#378ADD",
          600: "#185FA5",
          800: "#0C447C",
        },
      },
    },
  },
  plugins: [],
};

export default config;
