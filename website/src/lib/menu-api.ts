import fallbackMenu from "../data/menu.json";

const apiUrl = import.meta.env.API_URL?.replace(/\/$/, "");
const restaurantSlug = import.meta.env.RESTAURANT_SLUG;

export async function loadMenu() {
  if (!apiUrl || !restaurantSlug) return fallbackMenu;

  try {
    const response = await fetch(
      `${apiUrl}/api/public/restaurants/${encodeURIComponent(restaurantSlug)}/menu`,
    );
    if (!response.ok) throw new Error(`Menu API returned ${response.status}`);
    return await response.json();
  } catch (error) {
    console.warn("Menu API unavailable; using bundled fallback menu.", error);
    return fallbackMenu;
  }
}
