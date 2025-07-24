/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{js,ts,jsx,tsx}"],
  theme: {
    extend: {
      colors: {
        primary: "#8E44FF", // Purple
        secondary: "#1ABC9C", // Teal
        accent: "#F1C40F", // Yellow for rewards
      },
      fontFamily: {
        sans: ["Open Sans", "sans-serif"], // Default for body
        livvic: ["Livvic", "sans-serif"],
        "open-sans": ["Open Sans", "sans-serif"],
      },
      backdropBlur: {
        xs: "2px",
      },
    },
  },
  plugins: [],
};
