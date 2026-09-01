# encoding: UTF-8

module PZHardcoreNuzlocke
  module Config
    VERSION = 1

    DEFAULT_RULES = {
      :permadeath      => true,
      :first_encounter => true,
      :one_per_area    => true,
      :dupes_clause    => true,
      :species_clause  => true,
      :shiny_clause    => true,
      :level_caps      => true,
      :no_battle_items => true,
      :set_style       => true,
      :count_gifts     => false,
      :count_statics   => true,
      :shared_methods  => true,
      :subzones        => false
    }

    FORCED_RULES = [:permadeath, :first_encounter, :one_per_area]

    CONFIGURABLE_RULES = [
      [:dupes_clause,    :rule_dupes_clause],
      [:species_clause,  :rule_species_clause],
      [:shiny_clause,    :rule_shiny_clause],
      [:level_caps,      :rule_level_caps],
      [:no_battle_items, :rule_no_battle_items],
      [:set_style,       :rule_set_style],
      [:count_gifts,     :rule_count_gifts],
      [:count_statics,   :rule_count_statics],
      [:shared_methods,  :rule_shared_methods],
      [:subzones,        :rule_subzones]
    ]

    # Pokemon Z already exposes these progression switches and caps in its UI.
    # Keeping a local table makes the challenge independent from packed scripts.
    LEVEL_CAPS = [
      [nil, 17], [88, 27], [97, 36], [150, 42], [211, 50],
      [326, 56], [502, 70], [503, 75], [504, 80], [505, 85],
      [506, 94], [744, 100]
    ]

    CEMETERY_NAME = "CEMENTERIO"
    PAUSE_SHORTCUT = :R
  end
end
