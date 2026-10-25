-- Auctionary 2.0 - Copyright (c) 2026 Feralpaw - MIT licence, see LICENSE.txt
local Auctionary = Auctionary2

---- Texts in the player's language
-- English is the base; another language only replaces the texts it has.
-- Every text is also put into a global AUCTIONARY2_L_<KEY>.

local languages = AUCTIONARY2_LOCALES or {}
local texts = languages.enUS and languages.enUS() or {}
local own = GetLocale() ~= "enUS" and languages[GetLocale()]
if own then
  for key, value in pairs(own()) do
    texts[key] = value
  end
end

for key, value in pairs(texts) do
  value = value:gsub("\\n", "\n")
  texts[key] = value
  _G["AUCTIONARY2_L_" .. key] = value
end

function Auctionary.Locales.Apply(key, ...)
  local text = texts[key]
  if text == nil then
    error("Missing text '" .. tostring(key) .. "'")
  end
  if select("#", ...) > 0 then
    return text:format(...)
  end
  return text
end

-- The other languages are not needed any more
AUCTIONARY2_LOCALES = nil
