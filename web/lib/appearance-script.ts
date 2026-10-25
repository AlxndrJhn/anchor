/**
 * Runs before the first paint, from the saved preferences, so a chosen
 * scheme doesn't flash Anchor's own colours on load.
 */
export const appearanceScript = `try{var u=(JSON.parse(localStorage.getItem("preferences"))||{}).state.ui||{};var h=document.documentElement;if(u.colorScheme&&u.colorScheme!=="anchor")h.dataset.scheme=u.colorScheme;if(u.style&&u.style!=="default")h.dataset.style=u.style}catch(e){}`;
