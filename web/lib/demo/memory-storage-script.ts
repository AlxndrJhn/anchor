/**
 * Runs first in the demo build: localStorage and sessionStorage are kept in
 * the page only, so nothing the demo does outlives a reload, and nothing of
 * the app at the site's root (same origin) is read or changed.
 */
export const memoryStorageScript = `(function(){function m(){var d=new Map();return{get length(){return d.size},key:function(i){var k=Array.from(d.keys())[i];return k===undefined?null:k},getItem:function(k){k=String(k);return d.has(k)?d.get(k):null},setItem:function(k,v){d.set(String(k),String(v))},removeItem:function(k){d.delete(String(k))},clear:function(){d.clear()}}}try{Object.defineProperty(window,"localStorage",{configurable:true,value:m()});Object.defineProperty(window,"sessionStorage",{configurable:true,value:m()})}catch(e){}})()`;
