local Auctionator = Auctionary

local currentLocale = {}

local function FixMissingTranslations(incomplete, locale)
  if locale == "enUS" then
    return
  end

  local enUS = AUCTIONARY_LOCALES["enUS"]()
  for key, val in pairs(enUS) do
    if incomplete[key] == nil then
      incomplete[key] = val
    end
  end
end

local function AddNewLines(full)
  for key, val in pairs(full) do
    full[key] = string.gsub(full[key], "\\n", "\n")
  end
end

if AUCTIONARY_LOCALES_OVERRIDE ~= nil then
  currentLocale = AUCTIONARY_LOCALES_OVERRIDE()

  FixMissingTranslations(currentLocale, "OVERRIDE")
elseif AUCTIONARY_LOCALES[GetLocale()] ~= nil then
  currentLocale = AUCTIONARY_LOCALES[GetLocale()]()

  FixMissingTranslations(currentLocale, GetLocale())
else
  currentLocale = AUCTIONARY_LOCALES["enUS"]()
end

AddNewLines(currentLocale)

-- Export constants into the global scope (for XML frames to use)
for key, value in pairs(currentLocale) do
  _G["AUCTIONARY_L_"..key] = value
end

function Auctionator.Locales.Apply(s, ...)
  if currentLocale[s] ~= nil then
    return string.format(currentLocale[s], ...)
  else
    error("Unknown/missing locale string '" .. s .. "'")
  end
end
