-- Auctionary 2.0 - Copyright (c) 2026 Feralpaw - MIT licence, see LICENSE.txt
local Auctionary = Auctionary2

---- What disenchanting, milling and prospecting give (Wrath of the Lich King)
-- Written as the rules of the game, not as one line per item:
--  * Disenchanting depends on quality, item level and whether the item is a
--    weapon or armour. Amounts within a range are equally likely.
--  * Milling: every herb of a tier gives that tier's pigment; the "higher"
--    herbs of a tier give more pigment and twice the chance of the rare one.
--  * Prospecting: the expected number of each gem per 5 ore.

local D = {}
Auctionary.Destroying = Auctionary.Destroying or {}
Auctionary.Destroying.Data = D

---- Materials: item ID and English name (shown until the client knows the item)
local M = {
  STRANGE_DUST = 10940, SOUL_DUST = 11083, VISION_DUST = 11137, DREAM_DUST = 11176,
  ILLUSION_DUST = 16204, ARCANE_DUST = 22445, INFINITE_DUST = 34054,

  LESSER_MAGIC = 10938, GREATER_MAGIC = 10939, LESSER_ASTRAL = 10998, GREATER_ASTRAL = 11082,
  LESSER_MYSTIC = 11134, GREATER_MYSTIC = 11135, LESSER_NETHER = 11174, GREATER_NETHER = 11175,
  LESSER_ETERNAL = 16202, GREATER_ETERNAL = 16203, LESSER_PLANAR = 22447, GREATER_PLANAR = 22446,
  LESSER_COSMIC = 34056, GREATER_COSMIC = 34055,

  SMALL_GLIMMERING = 10978, LARGE_GLIMMERING = 11084, SMALL_GLOWING = 11138, LARGE_GLOWING = 11139,
  SMALL_RADIANT = 11177, LARGE_RADIANT = 11178, SMALL_BRILLIANT = 14343, LARGE_BRILLIANT = 14344,
  SMALL_PRISMATIC = 22448, LARGE_PRISMATIC = 22449, SMALL_DREAM = 34053, DREAM_SHARD = 34052,

  NEXUS_CRYSTAL = 20725, VOID_CRYSTAL = 22450, ABYSS_CRYSTAL = 34057,
}
D.Materials = M

D.MaterialNames = {
  [M.STRANGE_DUST] = "Strange Dust", [M.SOUL_DUST] = "Soul Dust", [M.VISION_DUST] = "Vision Dust",
  [M.DREAM_DUST] = "Dream Dust", [M.ILLUSION_DUST] = "Illusion Dust", [M.ARCANE_DUST] = "Arcane Dust",
  [M.INFINITE_DUST] = "Infinite Dust",
  [M.LESSER_MAGIC] = "Lesser Magic Essence", [M.GREATER_MAGIC] = "Greater Magic Essence",
  [M.LESSER_ASTRAL] = "Lesser Astral Essence", [M.GREATER_ASTRAL] = "Greater Astral Essence",
  [M.LESSER_MYSTIC] = "Lesser Mystic Essence", [M.GREATER_MYSTIC] = "Greater Mystic Essence",
  [M.LESSER_NETHER] = "Lesser Nether Essence", [M.GREATER_NETHER] = "Greater Nether Essence",
  [M.LESSER_ETERNAL] = "Lesser Eternal Essence", [M.GREATER_ETERNAL] = "Greater Eternal Essence",
  [M.LESSER_PLANAR] = "Lesser Planar Essence", [M.GREATER_PLANAR] = "Greater Planar Essence",
  [M.LESSER_COSMIC] = "Lesser Cosmic Essence", [M.GREATER_COSMIC] = "Greater Cosmic Essence",
  [M.SMALL_GLIMMERING] = "Small Glimmering Shard", [M.LARGE_GLIMMERING] = "Large Glimmering Shard",
  [M.SMALL_GLOWING] = "Small Glowing Shard", [M.LARGE_GLOWING] = "Large Glowing Shard",
  [M.SMALL_RADIANT] = "Small Radiant Shard", [M.LARGE_RADIANT] = "Large Radiant Shard",
  [M.SMALL_BRILLIANT] = "Small Brilliant Shard", [M.LARGE_BRILLIANT] = "Large Brilliant Shard",
  [M.SMALL_PRISMATIC] = "Small Prismatic Shard", [M.LARGE_PRISMATIC] = "Large Prismatic Shard",
  [M.SMALL_DREAM] = "Small Dream Shard", [M.DREAM_SHARD] = "Dream Shard",
  [M.NEXUS_CRYSTAL] = "Nexus Crystal", [M.VOID_CRYSTAL] = "Void Crystal", [M.ABYSS_CRYSTAL] = "Abyss Crystal",
}

-- Three lesser essences make one greater (and back), so a lesser essence is
-- worth at most a third of the greater one
D.LesserToGreater = {
  [M.LESSER_MAGIC] = M.GREATER_MAGIC, [M.LESSER_ASTRAL] = M.GREATER_ASTRAL,
  [M.LESSER_MYSTIC] = M.GREATER_MYSTIC, [M.LESSER_NETHER] = M.GREATER_NETHER,
  [M.LESSER_ETERNAL] = M.GREATER_ETERNAL, [M.LESSER_PLANAR] = M.GREATER_PLANAR,
  [M.LESSER_COSMIC] = M.GREATER_COSMIC,
}

---- Disenchanting

-- Uncommon (green) items: item levels, then dust, essence and shard with
-- their amounts (min, max). The split decides how often each comes up.
D.Uncommon = {
  { 5, 15,   M.STRANGE_DUST, 1, 2,   M.LESSER_MAGIC, 1, 2,    false, "noShard" },
  { 16, 20,  M.STRANGE_DUST, 2, 3,   M.GREATER_MAGIC, 1, 2,   M.SMALL_GLIMMERING },
  { 21, 25,  M.STRANGE_DUST, 4, 6,   M.LESSER_ASTRAL, 1, 2,   M.SMALL_GLIMMERING, "bigShard" },
  { 26, 30,  M.SOUL_DUST, 1, 2,      M.GREATER_ASTRAL, 1, 2,  M.LARGE_GLIMMERING },
  { 31, 35,  M.SOUL_DUST, 2, 5,      M.LESSER_MYSTIC, 1, 2,   M.SMALL_GLOWING },
  { 36, 40,  M.VISION_DUST, 1, 2,    M.GREATER_MYSTIC, 1, 2,  M.LARGE_GLOWING },
  { 41, 45,  M.VISION_DUST, 2, 5,    M.LESSER_NETHER, 1, 2,   M.SMALL_RADIANT },
  { 46, 50,  M.DREAM_DUST, 1, 2,     M.GREATER_NETHER, 1, 2,  M.LARGE_RADIANT },
  { 51, 55,  M.DREAM_DUST, 2, 5,     M.LESSER_ETERNAL, 1, 2,  M.SMALL_BRILLIANT },
  { 56, 60,  M.ILLUSION_DUST, 1, 2,  M.GREATER_ETERNAL, 1, 2, M.LARGE_BRILLIANT },
  { 61, 65,  M.ILLUSION_DUST, 2, 5,  M.GREATER_ETERNAL, 2, 3, M.LARGE_BRILLIANT },
  { 66, 80,  M.ARCANE_DUST, 1, 3,    M.LESSER_PLANAR, 1, 3,   M.SMALL_PRISMATIC, "outland" },
  { 81, 99,  M.ARCANE_DUST, 2, 3,    M.LESSER_PLANAR, 2, 3,   M.SMALL_PRISMATIC, "outland" },
  { 100, 120, M.ARCANE_DUST, 2, 5,   M.GREATER_PLANAR, 1, 2,  M.LARGE_PRISMATIC, "outland" },
  { 121, 151, M.INFINITE_DUST, 1, 3, M.LESSER_COSMIC, 1, 2,   M.SMALL_DREAM, "outland" },
  { 152, 200, M.INFINITE_DUST, 4, 7, M.GREATER_COSMIC, 1, 2,  M.DREAM_SHARD, "outland" },
}

-- Percent for dust, essence, shard. Armour gives mostly dust, weapons mostly
-- essence; from Outland on the shard chance is lower.
D.UncommonSplit = {
  ARMOR = { normal = { 75, 20, 5 }, bigShard = { 75, 15, 10 }, outland = { 75, 22, 3 }, noShard = { 80, 20, 0 } },
  WEAPON = { normal = { 20, 75, 5 }, bigShard = { 15, 75, 10 }, outland = { 22, 75, 3 }, noShard = { 20, 80, 0 } },
}

-- Rare (blue) items: one shard, from level 56 on with a small chance of a crystal
D.Rare = {
  { 11, 25, M.SMALL_GLIMMERING }, { 26, 30, M.LARGE_GLIMMERING },
  { 31, 35, M.SMALL_GLOWING }, { 36, 40, M.LARGE_GLOWING },
  { 41, 45, M.SMALL_RADIANT }, { 46, 50, M.LARGE_RADIANT },
  { 51, 55, M.SMALL_BRILLIANT }, { 56, 65, M.LARGE_BRILLIANT, M.NEXUS_CRYSTAL },
  { 66, 99, M.SMALL_PRISMATIC, M.NEXUS_CRYSTAL }, { 100, 120, M.LARGE_PRISMATIC, M.VOID_CRYSTAL },
  { 121, 164, M.SMALL_DREAM, M.ABYSS_CRYSTAL }, { 165, 300, M.DREAM_SHARD, M.ABYSS_CRYSTAL },
}
D.RareCrystalPercent = 0.5

-- Epic (purple) items: one material, amount min..max ("mostlyMax": the
-- higher amount comes twice as often as the lower one)
D.Epic = {
  { 40, 45, M.SMALL_RADIANT, 2, 4 }, { 46, 50, M.LARGE_RADIANT, 2, 4 },
  { 51, 55, M.SMALL_BRILLIANT, 2, 4 }, { 56, 60, M.NEXUS_CRYSTAL, 1, 1 },
  { 61, 94, M.NEXUS_CRYSTAL, 1, 2 }, { 95, 104, M.VOID_CRYSTAL, 1, 2 },
  { 105, 164, M.VOID_CRYSTAL, 1, 2, "mostlyMax" }, { 165, 300, M.ABYSS_CRYSTAL, 1, 1 },
}

---- Milling: per tier the pigment, the rare pigment and the herbs.
-- Lower herbs: 2-3 pigments, the rare one in about a quarter of the mills.
-- Higher herbs: 2-4 pigments, the rare one in about half of them.
D.MillTiers = {
  { pigment = 39151, -- Alabaster
    lower = { 2447, 765 }, higher = { 2449 } },          -- Peacebloom, Silverleaf / Earthroot
  { pigment = 39334, rare = 43103, -- Dusky / Verdant
    lower = { 785, 2450, 2452 }, higher = { 3820, 2453 } }, -- Mageroyal, Briarthorn, Swiftthistle / Stranglekelp, Bruiseweed
  { pigment = 39338, rare = 43104, -- Golden / Burnt
    lower = { 3355, 3369 }, higher = { 3356, 3357 } },   -- Wild Steelbloom, Grave Moss / Kingsblood, Liferoot
  { pigment = 39339, rare = 43105, -- Emerald / Indigo
    lower = { 3818, 3821 }, higher = { 3358, 3819 }, higherAmounts = { 3, 4 } }, -- Fadeleaf, Goldthorn / Khadgar's Whisker, Wintersbite
  { pigment = 39340, rare = 43106, -- Violet / Ruby
    lower = { 4625, 8831, 8836, 8838 }, higher = { 8839, 8845, 8846 } },
  { pigment = 39341, rare = 43107, -- Silvery / Sapphire
    lower = { 13464, 13463 }, higher = { 13465, 13466, 13467 } },
  { pigment = 39342, rare = 43108, -- Nether / Ebon
    lower = { 22785, 22786, 22787, 22789 }, higher = { 22790, 22791, 22792, 22793 } },
  { pigment = 39343, rare = 43109, -- Azure / Icy
    lower = { 36901, 37921, 39970, 36904, 36907 }, higher = { 36903, 36905, 36906 } },
}
D.MillLower = { amounts = { 2, 3 }, rare = 0.27 }
D.MillHigher = { amounts = { 2, 4 }, rare = 0.53 }

---- Prospecting: expected number of each gem per 5 ore
local function Each(chance, gems)
  local result = {}
  for _, gem in ipairs(gems) do
    result[gem] = chance
  end
  return result
end

local function Join(...)
  local result = {}
  for _, part in ipairs({ ... }) do
    for gem, chance in pairs(part) do
      result[gem] = chance
    end
  end
  return result
end

local TBC_GREEN = { 23077, 23079, 21929, 23112, 23107, 23117 }  -- Blood Garnet ... Azure Moonstone
local TBC_BLUE = { 23439, 23440, 23436, 23441, 23438, 23437 }   -- Noble Topaz ... Talasite
local WOTLK_GREEN = { 36917, 36923, 36932, 36929, 36926, 36920 } -- Bloodstone ... Sun Crystal
local WOTLK_BLUE = { 36921, 36933, 36930, 36918, 36924, 36927 }  -- Autumn's Glow ... Twilight Opal
local WOTLK_EPIC = { 36919, 36928, 36934, 36922, 36925 }         -- Cardinal Ruby ... Majestic Zircon

D.Prospect = {
  [2770] = { [818] = 0.5, [774] = 0.5, [1210] = 0.1 },                         -- Copper
  [2771] = Join(Each(0.39, { 1210, 1705, 1206 }), Each(0.03, { 3864, 1529, 7909 })), -- Tin
  [2772] = Join(Each(0.37, { 3864, 1705, 1529 }), Each(0.05, { 7909, 7910 })),      -- Iron
  [3858] = Join(Each(0.37, { 7910, 7909, 3864 }), Each(0.03, { 12361, 12799 }),
                Each(0.02, { 12800, 12364 })),                                  -- Mithril
  [10620] = Join(Each(0.32, { 12800, 12361, 12364, 12799 }), { [7910] = 0.16 }),  -- Thorium
  [23424] = Join(Each(0.185, TBC_GREEN), Each(0.012, TBC_BLUE)),                -- Fel Iron
  [23425] = Join({ [24243] = 1 }, Each(0.185, TBC_GREEN), Each(0.04, TBC_BLUE)), -- Adamantite
  [36909] = Join(Each(0.25, WOTLK_GREEN), Each(0.013, WOTLK_BLUE)),             -- Cobalt
  [36912] = Join(Each(0.185, WOTLK_GREEN), Each(0.04, WOTLK_BLUE)),             -- Saronite
  [36910] = Join({ [46849] = 0.72, [36931] = 0.05 }, Each(0.245, WOTLK_GREEN),
                 Each(0.04, WOTLK_BLUE), Each(0.04, WOTLK_EPIC)),               -- Titanium
}
