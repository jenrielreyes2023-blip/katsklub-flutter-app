import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

/// Configuration definition for a profile effect.
class ProfileEffectConfig {
  final String id;
  final String name;
  final String introUrl;
  final String loopUrl;
  final Duration introDuration;
  final double aspectRatio;

  const ProfileEffectConfig({
    required this.id,
    required this.name,
    required this.introUrl,
    required this.loopUrl,
    this.introDuration = const Duration(milliseconds: 2880),
    this.aspectRatio = 450 / 880,
  });

  static const Map<String, ProfileEffectConfig> registry = {
    'zombie_slime': ProfileEffectConfig(
      id: 'zombie_slime',
      name: 'Zombie Slime',
      introUrl: 'https://media.katsklub.top/effects/zombie-slime/intro_v2.webp',
      loopUrl: 'https://media.katsklub.top/effects/zombie-slime/loop_v2.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'zombie-slime': ProfileEffectConfig(
      id: 'zombie-slime',
      name: 'Zombie Slime',
      introUrl: 'https://media.katsklub.top/effects/zombie-slime/intro_v2.webp',
      loopUrl: 'https://media.katsklub.top/effects/zombie-slime/loop_v2.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'cloud_nine': ProfileEffectConfig(
      id: 'cloud_nine',
      name: 'Cloud Nine',
      introUrl: 'https://media.katsklub.top/effects/cloud-nine/intro_v2.webp',
      loopUrl: 'https://media.katsklub.top/effects/cloud-nine/loop_v2.webp',
      introDuration: Duration(milliseconds: 5000),
    ),
    'cloud-nine': ProfileEffectConfig(
      id: 'cloud-nine',
      name: 'Cloud Nine',
      introUrl: 'https://media.katsklub.top/effects/cloud-nine/intro_v2.webp',
      loopUrl: 'https://media.katsklub.top/effects/cloud-nine/loop_v2.webp',
      introDuration: Duration(milliseconds: 5000),
    ),
    'falling_stars': ProfileEffectConfig(
      id: 'falling_stars',
      name: 'Falling Stars',
      introUrl: 'https://media.katsklub.top/effects/falling-stars/intro_v2.webp',
      loopUrl: 'https://media.katsklub.top/effects/falling-stars/loop_v2.webp',
      introDuration: Duration(milliseconds: 4920),
    ),
    'falling-stars': ProfileEffectConfig(
      id: 'falling-stars',
      name: 'Falling Stars',
      introUrl: 'https://media.katsklub.top/effects/falling-stars/intro_v2.webp',
      loopUrl: 'https://media.katsklub.top/effects/falling-stars/loop_v2.webp',
      introDuration: Duration(milliseconds: 4920),
    ),
    'la_llorona': ProfileEffectConfig(
      id: 'la_llorona',
      name: 'La Llorona',
      introUrl: 'https://media.katsklub.top/effects/la-llorona/intro_v2.webp',
      loopUrl: 'https://media.katsklub.top/effects/la-llorona/loop_v3.webp',
      introDuration: Duration(milliseconds: 5000),
    ),
    'la-llorona': ProfileEffectConfig(
      id: 'la-llorona',
      name: 'La Llorona',
      introUrl: 'https://media.katsklub.top/effects/la-llorona/intro_v2.webp',
      loopUrl: 'https://media.katsklub.top/effects/la-llorona/loop_v3.webp',
      introDuration: Duration(milliseconds: 5000),
    ),
    'boost_relic': ProfileEffectConfig(
      id: 'boost_relic',
      name: 'Boost Relic',
      introUrl: 'https://media.katsklub.top/effects/boost-relic/intro_v2.webp',
      loopUrl: 'https://media.katsklub.top/effects/boost-relic/loop_v2.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'boost-relic': ProfileEffectConfig(
      id: 'boost-relic',
      name: 'Boost Relic',
      introUrl: 'https://media.katsklub.top/effects/boost-relic/intro_v2.webp',
      loopUrl: 'https://media.katsklub.top/effects/boost-relic/loop_v2.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'cyberspace': ProfileEffectConfig(
      id: 'cyberspace',
      name: 'Cyberspace',
      introUrl: 'https://media.katsklub.top/effects/cyberspace/intro_v2.webp',
      loopUrl: 'https://media.katsklub.top/effects/cyberspace/loop_v2.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'hydro_blast': ProfileEffectConfig(
      id: 'hydro_blast',
      name: 'Hydro Blast',
      introUrl: 'https://media.katsklub.top/effects/hydro-blast/intro_v2.webp',
      loopUrl: 'https://media.katsklub.top/effects/hydro-blast/loop_v2.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'hydro-blast': ProfileEffectConfig(
      id: 'hydro-blast',
      name: 'Hydro Blast',
      introUrl: 'https://media.katsklub.top/effects/hydro-blast/intro_v2.webp',
      loopUrl: 'https://media.katsklub.top/effects/hydro-blast/loop_v2.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'shatter': ProfileEffectConfig(
      id: 'shatter',
      name: 'Shatter',
      introUrl: 'https://media.katsklub.top/effects/shatter/intro_v2.webp',
      loopUrl: 'https://media.katsklub.top/effects/shatter/loop_v2.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'magic_hearts': ProfileEffectConfig(
      id: 'magic_hearts',
      name: 'Magic Hearts',
      introUrl: 'https://media.katsklub.top/effects/magic-hearts/intro_v2.webp',
      loopUrl: 'https://media.katsklub.top/effects/magic-hearts/loop_v2.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'magic-hearts': ProfileEffectConfig(
      id: 'magic-hearts',
      name: 'Magic Hearts',
      introUrl: 'https://media.katsklub.top/effects/magic-hearts/intro_v2.webp',
      loopUrl: 'https://media.katsklub.top/effects/magic-hearts/loop_v2.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'sakura_dreams': ProfileEffectConfig(
      id: 'sakura_dreams',
      name: 'Sakura Dreams',
      introUrl: 'https://media.katsklub.top/effects/sakura-dreams/intro_v2.webp',
      loopUrl: 'https://media.katsklub.top/effects/sakura-dreams/loop_v2.webp',
      introDuration: Duration(milliseconds: 3000),
    ),
    'sakura-dreams': ProfileEffectConfig(
      id: 'sakura-dreams',
      name: 'Sakura Dreams',
      introUrl: 'https://media.katsklub.top/effects/sakura-dreams/intro_v2.webp',
      loopUrl: 'https://media.katsklub.top/effects/sakura-dreams/loop_v2.webp',
      introDuration: Duration(milliseconds: 3000),
    ),
    'power_surge': ProfileEffectConfig(
      id: 'power_surge',
      name: 'Power Surge',
      introUrl: 'https://media.katsklub.top/effects/power-surge/intro_v2.webp',
      loopUrl: 'https://media.katsklub.top/effects/power-surge/loop_v2.webp',
      introDuration: Duration(milliseconds: 2400),
    ),
    'power-surge': ProfileEffectConfig(
      id: 'power-surge',
      name: 'Power Surge',
      introUrl: 'https://media.katsklub.top/effects/power-surge/intro_v2.webp',
      loopUrl: 'https://media.katsklub.top/effects/power-surge/loop_v2.webp',
      introDuration: Duration(milliseconds: 2400),
    ),
    'shuriken_strike': ProfileEffectConfig(
      id: 'shuriken_strike',
      name: 'Shuriken Strike',
      introUrl: 'https://media.katsklub.top/effects/shuriken-strike/intro_v2.webp',
      loopUrl: 'https://media.katsklub.top/effects/shuriken-strike/loop_v2.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'shuriken-strike': ProfileEffectConfig(
      id: 'shuriken-strike',
      name: 'Shuriken Strike',
      introUrl: 'https://media.katsklub.top/effects/shuriken-strike/intro_v2.webp',
      loopUrl: 'https://media.katsklub.top/effects/shuriken-strike/loop_v2.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'mystic_vines': ProfileEffectConfig(
      id: 'mystic_vines',
      name: 'Mystic Vines',
      introUrl: 'https://media.katsklub.top/effects/mystic-vines/intro_v2.webp',
      loopUrl: 'https://media.katsklub.top/effects/mystic-vines/loop_v2.webp',
      introDuration: Duration(milliseconds: 3070),
    ),
    'mystic-vines': ProfileEffectConfig(
      id: 'mystic-vines',
      name: 'Mystic Vines',
      introUrl: 'https://media.katsklub.top/effects/mystic-vines/intro_v2.webp',
      loopUrl: 'https://media.katsklub.top/effects/mystic-vines/loop_v2.webp',
      introDuration: Duration(milliseconds: 3070),
    ),
    'pixie_dust': ProfileEffectConfig(
      id: 'pixie_dust',
      name: 'Pixie Dust',
      introUrl: 'https://media.katsklub.top/effects/pixie-dust/loop_v2.webp',
      loopUrl: 'https://media.katsklub.top/effects/pixie-dust/loop_v2.webp',
      introDuration: Duration.zero,
    ),
    'pixie-dust': ProfileEffectConfig(
      id: 'pixie-dust',
      name: 'Pixie Dust',
      introUrl: 'https://media.katsklub.top/effects/pixie-dust/loop_v2.webp',
      loopUrl: 'https://media.katsklub.top/effects/pixie-dust/loop_v2.webp',
      introDuration: Duration.zero,
    ),
    'discord_os': ProfileEffectConfig(
      id: 'discord_os',
      name: 'Discord OS',
      introUrl: 'https://media.katsklub.top/effects/discord-os/intro_v2.webp',
      loopUrl: 'https://media.katsklub.top/effects/discord-os/loop_v2.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'discord-os': ProfileEffectConfig(
      id: 'discord-os',
      name: 'Discord OS',
      introUrl: 'https://media.katsklub.top/effects/discord-os/intro_v2.webp',
      loopUrl: 'https://media.katsklub.top/effects/discord-os/loop_v2.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'breakfast_plate': ProfileEffectConfig(
      id: 'breakfast_plate',
      name: 'Breakfast Plate',
      introUrl: 'https://media.katsklub.top/effects/breakfast-plate/intro_v2.webp',
      loopUrl: 'https://media.katsklub.top/effects/breakfast-plate/loop_v2.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'breakfast-plate': ProfileEffectConfig(
      id: 'breakfast-plate',
      name: 'Breakfast Plate',
      introUrl: 'https://media.katsklub.top/effects/breakfast-plate/intro_v2.webp',
      loopUrl: 'https://media.katsklub.top/effects/breakfast-plate/loop_v2.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'ghoulish_graffiti': ProfileEffectConfig(
      id: 'ghoulish_graffiti',
      name: 'Ghoulish Graffiti',
      introUrl: 'https://media.katsklub.top/effects/ghoulish-graffiti/intro_v2.webp',
      loopUrl: 'https://media.katsklub.top/effects/ghoulish-graffiti/loop_v2.webp',
      introDuration: Duration(milliseconds: 2570),
    ),
    'ghoulish-graffiti': ProfileEffectConfig(
      id: 'ghoulish-graffiti',
      name: 'Ghoulish Graffiti',
      introUrl: 'https://media.katsklub.top/effects/ghoulish-graffiti/intro_v2.webp',
      loopUrl: 'https://media.katsklub.top/effects/ghoulish-graffiti/loop_v2.webp',
      introDuration: Duration(milliseconds: 2570),
    ),
    'dark_omens': ProfileEffectConfig(
      id: 'dark_omens',
      name: 'Dark Omens',
      introUrl: 'https://media.katsklub.top/effects/dark-omens/intro_v2.webp',
      loopUrl: 'https://media.katsklub.top/effects/dark-omens/loop_v2.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'dark-omens': ProfileEffectConfig(
      id: 'dark-omens',
      name: 'Dark Omens',
      introUrl: 'https://media.katsklub.top/effects/dark-omens/intro_v2.webp',
      loopUrl: 'https://media.katsklub.top/effects/dark-omens/loop_v2.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'fall_foliage': ProfileEffectConfig(
      id: 'fall_foliage',
      name: 'Fall Foliage',
      introUrl: 'https://media.katsklub.top/effects/fall-foliage/intro_v2.webp',
      loopUrl: 'https://media.katsklub.top/effects/fall-foliage/loop_v2.webp',
      introDuration: Duration(milliseconds: 2990),
    ),
    'fall-foliage': ProfileEffectConfig(
      id: 'fall-foliage',
      name: 'Fall Foliage',
      introUrl: 'https://media.katsklub.top/effects/fall-foliage/intro_v2.webp',
      loopUrl: 'https://media.katsklub.top/effects/fall-foliage/loop_v2.webp',
      introDuration: Duration(milliseconds: 2990),
    ),
    'all_nighter': ProfileEffectConfig(
      id: 'all_nighter',
      name: 'All Nighter',
      introUrl: 'https://media.katsklub.top/effects/all-nighter/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/all-nighter/loop.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'all-nighter': ProfileEffectConfig(
      id: 'all-nighter',
      name: 'All Nighter',
      introUrl: 'https://media.katsklub.top/effects/all-nighter/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/all-nighter/loop.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'arcane_summons': ProfileEffectConfig(
      id: 'arcane_summons',
      name: 'Arcane Summons',
      introUrl: 'https://media.katsklub.top/effects/arcane-summons/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/arcane-summons/loop.webp',
      introDuration: Duration(milliseconds: 4720),
    ),
    'arcane-summons': ProfileEffectConfig(
      id: 'arcane-summons',
      name: 'Arcane Summons',
      introUrl: 'https://media.katsklub.top/effects/arcane-summons/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/arcane-summons/loop.webp',
      introDuration: Duration(milliseconds: 4720),
    ),
    'clove_s_ruse': ProfileEffectConfig(
      id: 'clove_s_ruse',
      name: 'Clove\'s Ruse',
      introUrl: 'https://media.katsklub.top/effects/clove-s-ruse/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/clove-s-ruse/loop.webp',
      introDuration: Duration(milliseconds: 5041),
    ),
    'clove-s-ruse': ProfileEffectConfig(
      id: 'clove-s-ruse',
      name: 'Clove\'s Ruse',
      introUrl: 'https://media.katsklub.top/effects/clove-s-ruse/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/clove-s-ruse/loop.webp',
      introDuration: Duration(milliseconds: 5041),
    ),
    'deck_the_halls': ProfileEffectConfig(
      id: 'deck_the_halls',
      name: 'Deck the Halls',
      introUrl: 'https://media.katsklub.top/effects/deck-the-halls/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/deck-the-halls/loop.webp',
      introDuration: Duration(milliseconds: 1680),
    ),
    'deck-the-halls': ProfileEffectConfig(
      id: 'deck-the-halls',
      name: 'Deck the Halls',
      introUrl: 'https://media.katsklub.top/effects/deck-the-halls/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/deck-the-halls/loop.webp',
      introDuration: Duration(milliseconds: 1680),
    ),
    'doodlebob_takeover': ProfileEffectConfig(
      id: 'doodlebob_takeover',
      name: 'DoodleBob Takeover',
      introUrl: 'https://media.katsklub.top/effects/doodlebob-takeover/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/doodlebob-takeover/loop.webp',
      introDuration: Duration(milliseconds: 4640),
    ),
    'doodlebob-takeover': ProfileEffectConfig(
      id: 'doodlebob-takeover',
      name: 'DoodleBob Takeover',
      introUrl: 'https://media.katsklub.top/effects/doodlebob-takeover/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/doodlebob-takeover/loop.webp',
      introDuration: Duration(milliseconds: 4640),
    ),
    'dragon_dance': ProfileEffectConfig(
      id: 'dragon_dance',
      name: 'Dragon Dance',
      introUrl: 'https://media.katsklub.top/effects/dragon-dance/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/dragon-dance/loop.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'dragon-dance': ProfileEffectConfig(
      id: 'dragon-dance',
      name: 'Dragon Dance',
      introUrl: 'https://media.katsklub.top/effects/dragon-dance/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/dragon-dance/loop.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'dreamy': ProfileEffectConfig(
      id: 'dreamy',
      name: 'Dreamy Cloud',
      introUrl: 'https://media.katsklub.top/effects/dreamy/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/dreamy/loop.webp',
      introDuration: Duration(milliseconds: 2999),
    ),
    'feelin_90s': ProfileEffectConfig(
      id: 'feelin_90s',
      name: 'Feelin\' 90s',
      introUrl: 'https://media.katsklub.top/effects/feelin-90s/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/feelin-90s/loop.webp',
      introDuration: Duration(milliseconds: 1416),
    ),
    'feelin-90s': ProfileEffectConfig(
      id: 'feelin-90s',
      name: 'Feelin\' 90s',
      introUrl: 'https://media.katsklub.top/effects/feelin-90s/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/feelin-90s/loop.webp',
      introDuration: Duration(milliseconds: 1416),
    ),
    'feelin_mischievous': ProfileEffectConfig(
      id: 'feelin_mischievous',
      name: 'Feelin\' Mischievous',
      introUrl: 'https://media.katsklub.top/effects/feelin-mischievous/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/feelin-mischievous/loop.webp',
      introDuration: Duration(milliseconds: 5079),
    ),
    'feelin-mischievous': ProfileEffectConfig(
      id: 'feelin-mischievous',
      name: 'Feelin\' Mischievous',
      introUrl: 'https://media.katsklub.top/effects/feelin-mischievous/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/feelin-mischievous/loop.webp',
      introDuration: Duration(milliseconds: 5079),
    ),
    'feelin_pizzazz': ProfileEffectConfig(
      id: 'feelin_pizzazz',
      name: 'Feelin\' Pizzazz',
      introUrl: 'https://media.katsklub.top/effects/feelin-pizzazz/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/feelin-pizzazz/loop.webp',
      introDuration: Duration(milliseconds: 1280),
    ),
    'feelin-pizzazz': ProfileEffectConfig(
      id: 'feelin-pizzazz',
      name: 'Feelin\' Pizzazz',
      introUrl: 'https://media.katsklub.top/effects/feelin-pizzazz/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/feelin-pizzazz/loop.webp',
      introDuration: Duration(milliseconds: 1280),
    ),
    'fellowship_of_the_spring': ProfileEffectConfig(
      id: 'fellowship_of_the_spring',
      name: 'Fellowship of the Spring',
      introUrl: 'https://media.katsklub.top/effects/fellowship-of-the-spring/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/fellowship-of-the-spring/loop.webp',
      introDuration: Duration(milliseconds: 2882),
    ),
    'fellowship-of-the-spring': ProfileEffectConfig(
      id: 'fellowship-of-the-spring',
      name: 'Fellowship of the Spring',
      introUrl: 'https://media.katsklub.top/effects/fellowship-of-the-spring/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/fellowship-of-the-spring/loop.webp',
      introDuration: Duration(milliseconds: 2882),
    ),
    'forgotten_treasure': ProfileEffectConfig(
      id: 'forgotten_treasure',
      name: 'Forgotten Treasure',
      introUrl: 'https://media.katsklub.top/effects/forgotten-treasure/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/forgotten-treasure/loop.webp',
      introDuration: Duration(milliseconds: 3521),
    ),
    'forgotten-treasure': ProfileEffectConfig(
      id: 'forgotten-treasure',
      name: 'Forgotten Treasure',
      introUrl: 'https://media.katsklub.top/effects/forgotten-treasure/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/forgotten-treasure/loop.webp',
      introDuration: Duration(milliseconds: 3521),
    ),
    'fortune_flurry': ProfileEffectConfig(
      id: 'fortune_flurry',
      name: 'Fortune Flurry',
      introUrl: 'https://media.katsklub.top/effects/fortune-flurry/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/fortune-flurry/loop.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'fortune-flurry': ProfileEffectConfig(
      id: 'fortune-flurry',
      name: 'Fortune Flurry',
      introUrl: 'https://media.katsklub.top/effects/fortune-flurry/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/fortune-flurry/loop.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'goozilla': ProfileEffectConfig(
      id: 'goozilla',
      name: 'Goozilla',
      introUrl: 'https://media.katsklub.top/effects/goozilla/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/goozilla/loop.webp',
      introDuration: Duration(milliseconds: 5425),
    ),
    'handsome_squidward': ProfileEffectConfig(
      id: 'handsome_squidward',
      name: 'Handsome Squidward',
      introUrl: 'https://media.katsklub.top/effects/handsome-squidward/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/handsome-squidward/loop.webp',
      introDuration: Duration(milliseconds: 4080),
    ),
    'handsome-squidward': ProfileEffectConfig(
      id: 'handsome-squidward',
      name: 'Handsome Squidward',
      introUrl: 'https://media.katsklub.top/effects/handsome-squidward/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/handsome-squidward/loop.webp',
      introDuration: Duration(milliseconds: 4080),
    ),
    'haunted_man_o_war': ProfileEffectConfig(
      id: 'haunted_man_o_war',
      name: 'Haunted Man O\' War',
      introUrl: 'https://media.katsklub.top/effects/haunted-man-o-war/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/haunted-man-o-war/loop.webp',
      introDuration: Duration(milliseconds: 3071),
    ),
    'haunted-man-o-war': ProfileEffectConfig(
      id: 'haunted-man-o-war',
      name: 'Haunted Man O\' War',
      introUrl: 'https://media.katsklub.top/effects/haunted-man-o-war/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/haunted-man-o-war/loop.webp',
      introDuration: Duration(milliseconds: 3071),
    ),
    'heartzilla': ProfileEffectConfig(
      id: 'heartzilla',
      name: 'Heartzilla',
      introUrl: 'https://media.katsklub.top/effects/heartzilla/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/heartzilla/loop.webp',
      introDuration: Duration(milliseconds: 3749),
    ),
    'jolly_roger': ProfileEffectConfig(
      id: 'jolly_roger',
      name: 'Jolly Roger',
      introUrl: 'https://media.katsklub.top/effects/jolly-roger/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/jolly-roger/loop.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'jolly-roger': ProfileEffectConfig(
      id: 'jolly-roger',
      name: 'Jolly Roger',
      introUrl: 'https://media.katsklub.top/effects/jolly-roger/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/jolly-roger/loop.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'ki_detonate': ProfileEffectConfig(
      id: 'ki_detonate',
      name: 'Ki Detonate',
      introUrl: 'https://media.katsklub.top/effects/ki-detonate/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/ki-detonate/loop.webp',
      introDuration: Duration(milliseconds: 2999),
    ),
    'ki-detonate': ProfileEffectConfig(
      id: 'ki-detonate',
      name: 'Ki Detonate',
      introUrl: 'https://media.katsklub.top/effects/ki-detonate/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/ki-detonate/loop.webp',
      introDuration: Duration(milliseconds: 2999),
    ),
    'lilypad_life': ProfileEffectConfig(
      id: 'lilypad_life',
      name: 'Lilypad Life',
      introUrl: 'https://media.katsklub.top/effects/lilypad-life/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/lilypad-life/loop.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'lilypad-life': ProfileEffectConfig(
      id: 'lilypad-life',
      name: 'Lilypad Life',
      introUrl: 'https://media.katsklub.top/effects/lilypad-life/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/lilypad-life/loop.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'mastery': ProfileEffectConfig(
      id: 'mastery',
      name: 'Grand Mastery',
      introUrl: 'https://media.katsklub.top/effects/mastery/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/mastery/loop.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'midnight_celebration': ProfileEffectConfig(
      id: 'midnight_celebration',
      name: 'Midnight Celebration',
      introUrl: 'https://media.katsklub.top/effects/midnight-celebration/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/midnight-celebration/loop.webp',
      introDuration: Duration(milliseconds: 2900),
    ),
    'midnight-celebration': ProfileEffectConfig(
      id: 'midnight-celebration',
      name: 'Midnight Celebration',
      introUrl: 'https://media.katsklub.top/effects/midnight-celebration/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/midnight-celebration/loop.webp',
      introDuration: Duration(milliseconds: 2900),
    ),
    'midnight_lilypad_life': ProfileEffectConfig(
      id: 'midnight_lilypad_life',
      name: 'Midnight Lilypad',
      introUrl: 'https://media.katsklub.top/effects/midnight-lilypad-life/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/midnight-lilypad-life/loop.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'midnight-lilypad-life': ProfileEffectConfig(
      id: 'midnight-lilypad-life',
      name: 'Midnight Lilypad',
      introUrl: 'https://media.katsklub.top/effects/midnight-lilypad-life/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/midnight-lilypad-life/loop.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'monster_pop': ProfileEffectConfig(
      id: 'monster_pop',
      name: 'Monster Pop',
      introUrl: 'https://media.katsklub.top/effects/monster-pop/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/monster-pop/loop.webp',
      introDuration: Duration(milliseconds: 3913),
    ),
    'monster-pop': ProfileEffectConfig(
      id: 'monster-pop',
      name: 'Monster Pop',
      introUrl: 'https://media.katsklub.top/effects/monster-pop/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/monster-pop/loop.webp',
      introDuration: Duration(milliseconds: 3913),
    ),
    'muddy_lilypad_life': ProfileEffectConfig(
      id: 'muddy_lilypad_life',
      name: 'Muddy Lilypad',
      introUrl: 'https://media.katsklub.top/effects/muddy-lilypad-life/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/muddy-lilypad-life/loop.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'muddy-lilypad-life': ProfileEffectConfig(
      id: 'muddy-lilypad-life',
      name: 'Muddy Lilypad',
      introUrl: 'https://media.katsklub.top/effects/muddy-lilypad-life/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/muddy-lilypad-life/loop.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'nice_profile': ProfileEffectConfig(
      id: 'nice_profile',
      name: 'Nice Profile',
      introUrl: 'https://media.katsklub.top/effects/nice-profile/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/nice-profile/loop.webp',
      introDuration: Duration(milliseconds: 4124),
    ),
    'nice-profile': ProfileEffectConfig(
      id: 'nice-profile',
      name: 'Nice Profile',
      introUrl: 'https://media.katsklub.top/effects/nice-profile/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/nice-profile/loop.webp',
      introDuration: Duration(milliseconds: 4124),
    ),
    'nightrunner': ProfileEffectConfig(
      id: 'nightrunner',
      name: 'Nightrunner',
      introUrl: 'https://media.katsklub.top/effects/nightrunner/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/nightrunner/loop.webp',
      introDuration: Duration(milliseconds: 2960),
    ),
    'petal_serenade': ProfileEffectConfig(
      id: 'petal_serenade',
      name: 'Petal Serenade',
      introUrl: 'https://media.katsklub.top/effects/petal-serenade/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/petal-serenade/loop.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'petal-serenade': ProfileEffectConfig(
      id: 'petal-serenade',
      name: 'Petal Serenade',
      introUrl: 'https://media.katsklub.top/effects/petal-serenade/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/petal-serenade/loop.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'rock_slide': ProfileEffectConfig(
      id: 'rock_slide',
      name: 'Rock Slide',
      introUrl: 'https://media.katsklub.top/effects/rock-slide/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/rock-slide/loop.webp',
      introDuration: Duration(milliseconds: 2962),
    ),
    'rock-slide': ProfileEffectConfig(
      id: 'rock-slide',
      name: 'Rock Slide',
      introUrl: 'https://media.katsklub.top/effects/rock-slide/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/rock-slide/loop.webp',
      introDuration: Duration(milliseconds: 2962),
    ),
    'saya': ProfileEffectConfig(
      id: 'saya',
      name: 'Saya',
      introUrl: 'https://media.katsklub.top/effects/saya/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/saya/loop.webp',
      introDuration: Duration(milliseconds: 3999),
    ),
    'shooting_stars': ProfileEffectConfig(
      id: 'shooting_stars',
      name: 'Shooting Stars',
      introUrl: 'https://media.katsklub.top/effects/shooting-stars/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/shooting-stars/loop.webp',
      introDuration: Duration(milliseconds: 3071),
    ),
    'shooting-stars': ProfileEffectConfig(
      id: 'shooting-stars',
      name: 'Shooting Stars',
      introUrl: 'https://media.katsklub.top/effects/shooting-stars/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/shooting-stars/loop.webp',
      introDuration: Duration(milliseconds: 3071),
    ),
    'snowy_shenanigans': ProfileEffectConfig(
      id: 'snowy_shenanigans',
      name: 'Snowy Shenanigans',
      introUrl: 'https://media.katsklub.top/effects/snowy-shenanigans/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/snowy-shenanigans/loop.webp',
      introDuration: Duration(milliseconds: 4166),
    ),
    'snowy-shenanigans': ProfileEffectConfig(
      id: 'snowy-shenanigans',
      name: 'Snowy Shenanigans',
      introUrl: 'https://media.katsklub.top/effects/snowy-shenanigans/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/snowy-shenanigans/loop.webp',
      introDuration: Duration(milliseconds: 4166),
    ),
    'space_evader': ProfileEffectConfig(
      id: 'space_evader',
      name: 'Space Evader',
      introUrl: 'https://media.katsklub.top/effects/space-evader/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/space-evader/loop.webp',
      introDuration: Duration(milliseconds: 4329),
    ),
    'space-evader': ProfileEffectConfig(
      id: 'space-evader',
      name: 'Space Evader',
      introUrl: 'https://media.katsklub.top/effects/space-evader/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/space-evader/loop.webp',
      introDuration: Duration(milliseconds: 4329),
    ),
    'spirit_flame': ProfileEffectConfig(
      id: 'spirit_flame',
      name: 'Spirit Flame',
      introUrl: 'https://media.katsklub.top/effects/spirit-flame/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/spirit-flame/loop.webp',
      introDuration: Duration(milliseconds: 2666),
    ),
    'spirit-flame': ProfileEffectConfig(
      id: 'spirit-flame',
      name: 'Spirit Flame',
      introUrl: 'https://media.katsklub.top/effects/spirit-flame/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/spirit-flame/loop.webp',
      introDuration: Duration(milliseconds: 2666),
    ),
    'spring_bloom': ProfileEffectConfig(
      id: 'spring_bloom',
      name: 'Spring Bloom',
      introUrl: 'https://media.katsklub.top/effects/spring-bloom/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/spring-bloom/loop.webp',
      introDuration: Duration(milliseconds: 6800),
    ),
    'spring-bloom': ProfileEffectConfig(
      id: 'spring-bloom',
      name: 'Spring Bloom',
      introUrl: 'https://media.katsklub.top/effects/spring-bloom/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/spring-bloom/loop.webp',
      introDuration: Duration(milliseconds: 6800),
    ),
    'study_spot': ProfileEffectConfig(
      id: 'study_spot',
      name: 'Study Spot',
      introUrl: 'https://media.katsklub.top/effects/study-spot/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/study-spot/loop.webp',
      introDuration: Duration(milliseconds: 2887),
    ),
    'study-spot': ProfileEffectConfig(
      id: 'study-spot',
      name: 'Study Spot',
      introUrl: 'https://media.katsklub.top/effects/study-spot/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/study-spot/loop.webp',
      introDuration: Duration(milliseconds: 2887),
    ),
    'supernova': ProfileEffectConfig(
      id: 'supernova',
      name: 'Supernova Burst',
      introUrl: 'https://media.katsklub.top/effects/supernova/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/supernova/loop.webp',
      introDuration: Duration(milliseconds: 3071),
    ),
    'sushi_mania': ProfileEffectConfig(
      id: 'sushi_mania',
      name: 'Sushi Mania',
      introUrl: 'https://media.katsklub.top/effects/sushi-mania/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/sushi-mania/loop.webp',
      introDuration: Duration(milliseconds: 2999),
    ),
    'sushi-mania': ProfileEffectConfig(
      id: 'sushi-mania',
      name: 'Sushi Mania',
      introUrl: 'https://media.katsklub.top/effects/sushi-mania/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/sushi-mania/loop.webp',
      introDuration: Duration(milliseconds: 2999),
    ),
    'the_immortal_clove': ProfileEffectConfig(
      id: 'the_immortal_clove',
      name: 'The Immortal Clove',
      introUrl: 'https://media.katsklub.top/effects/the-immortal-clove/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/the-immortal-clove/loop.webp',
      introDuration: Duration(milliseconds: 4916),
    ),
    'the-immortal-clove': ProfileEffectConfig(
      id: 'the-immortal-clove',
      name: 'The Immortal Clove',
      introUrl: 'https://media.katsklub.top/effects/the-immortal-clove/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/the-immortal-clove/loop.webp',
      introDuration: Duration(milliseconds: 4916),
    ),
    'tocotoco': ProfileEffectConfig(
      id: 'tocotoco',
      name: 'TocoToco',
      introUrl: 'https://media.katsklub.top/effects/tocotoco/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/tocotoco/loop.webp',
      introDuration: Duration(milliseconds: 2999),
    ),
    'turbo_drive': ProfileEffectConfig(
      id: 'turbo_drive',
      name: 'Turbo Drive',
      introUrl: 'https://media.katsklub.top/effects/turbo-drive/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/turbo-drive/loop.webp',
      introDuration: Duration(milliseconds: 2999),
    ),
    'turbo-drive': ProfileEffectConfig(
      id: 'turbo-drive',
      name: 'Turbo Drive',
      introUrl: 'https://media.katsklub.top/effects/turbo-drive/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/turbo-drive/loop.webp',
      introDuration: Duration(milliseconds: 2999),
    ),
    'twilight': ProfileEffectConfig(
      id: 'twilight',
      name: 'Twilight Shimmer',
      introUrl: 'https://media.katsklub.top/effects/twilight/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/twilight/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'twinkle_trails': ProfileEffectConfig(
      id: 'twinkle_trails',
      name: 'Twinkle Trails',
      introUrl: 'https://media.katsklub.top/effects/twinkle-trails/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/twinkle-trails/loop.webp',
      introDuration: Duration(milliseconds: 5760),
    ),
    'twinkle-trails': ProfileEffectConfig(
      id: 'twinkle-trails',
      name: 'Twinkle Trails',
      introUrl: 'https://media.katsklub.top/effects/twinkle-trails/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/twinkle-trails/loop.webp',
      introDuration: Duration(milliseconds: 5760),
    ),
    'uplink_error': ProfileEffectConfig(
      id: 'uplink_error',
      name: 'Uplink Error',
      introUrl: 'https://media.katsklub.top/effects/uplink-error/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/uplink-error/loop.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'uplink-error': ProfileEffectConfig(
      id: 'uplink-error',
      name: 'Uplink Error',
      introUrl: 'https://media.katsklub.top/effects/uplink-error/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/uplink-error/loop.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'vengeance': ProfileEffectConfig(
      id: 'vengeance',
      name: 'Vengeance',
      introUrl: 'https://media.katsklub.top/effects/vengeance/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/vengeance/loop.webp',
      introDuration: Duration(milliseconds: 3999),
    ),
    'vortex': ProfileEffectConfig(
      id: 'vortex',
      name: 'Mystic Vortex',
      introUrl: 'https://media.katsklub.top/effects/vortex/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/vortex/loop.webp',
      introDuration: Duration(milliseconds: 2480),
    ),
    'wake_up': ProfileEffectConfig(
      id: 'wake_up',
      name: 'Wake Up',
      introUrl: 'https://media.katsklub.top/effects/wake-up/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/wake-up/loop.webp',
      introDuration: Duration(milliseconds: 2999),
    ),
    'wake-up': ProfileEffectConfig(
      id: 'wake-up',
      name: 'Wake Up',
      introUrl: 'https://media.katsklub.top/effects/wake-up/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/wake-up/loop.webp',
      introDuration: Duration(milliseconds: 2999),
    ),
    'watercolors': ProfileEffectConfig(
      id: 'watercolors',
      name: 'Watercolors Splash',
      introUrl: 'https://media.katsklub.top/effects/watercolors/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/watercolors/loop.webp',
      introDuration: Duration(milliseconds: 2999),
    ),
    'akuma_s_wrath': ProfileEffectConfig(
      id: 'akuma_s_wrath',
      name: 'Akuma\'s Wrath',
      introUrl: 'https://media.katsklub.top/effects/akuma-s-wrath/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/akuma-s-wrath/loop.webp',
      introDuration: Duration(milliseconds: 2999),
    ),
    'akuma-s-wrath': ProfileEffectConfig(
      id: 'akuma-s-wrath',
      name: 'Akuma\'s Wrath',
      introUrl: 'https://media.katsklub.top/effects/akuma-s-wrath/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/akuma-s-wrath/loop.webp',
      introDuration: Duration(milliseconds: 2999),
    ),
    'arcane_epiphany': ProfileEffectConfig(
      id: 'arcane_epiphany',
      name: 'Arcane Epiphany',
      introUrl: 'https://media.katsklub.top/effects/arcane-epiphany/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/arcane-epiphany/loop.webp',
      introDuration: Duration(milliseconds: 4166),
    ),
    'arcane-epiphany': ProfileEffectConfig(
      id: 'arcane-epiphany',
      name: 'Arcane Epiphany',
      introUrl: 'https://media.katsklub.top/effects/arcane-epiphany/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/arcane-epiphany/loop.webp',
      introDuration: Duration(milliseconds: 4166),
    ),
    'aurora_dreams': ProfileEffectConfig(
      id: 'aurora_dreams',
      name: 'Aurora Dreams',
      introUrl: 'https://media.katsklub.top/effects/aurora-dreams/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/aurora-dreams/loop.webp',
      introDuration: Duration(milliseconds: 4999),
    ),
    'aurora-dreams': ProfileEffectConfig(
      id: 'aurora-dreams',
      name: 'Aurora Dreams',
      introUrl: 'https://media.katsklub.top/effects/aurora-dreams/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/aurora-dreams/loop.webp',
      introDuration: Duration(milliseconds: 4999),
    ),
    'autumn_equinox': ProfileEffectConfig(
      id: 'autumn_equinox',
      name: 'Autumn Equinox',
      introUrl: 'https://media.katsklub.top/effects/autumn-equinox/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/autumn-equinox/loop.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'autumn-equinox': ProfileEffectConfig(
      id: 'autumn-equinox',
      name: 'Autumn Equinox',
      introUrl: 'https://media.katsklub.top/effects/autumn-equinox/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/autumn-equinox/loop.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'beholder': ProfileEffectConfig(
      id: 'beholder',
      name: 'Beholder Eye',
      introUrl: 'https://media.katsklub.top/effects/beholder/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/beholder/loop.webp',
      introDuration: Duration(milliseconds: 3082),
    ),
    'blazing_ghoulish_graffiti': ProfileEffectConfig(
      id: 'blazing_ghoulish_graffiti',
      name: 'Blazing Graffiti',
      introUrl: 'https://media.katsklub.top/effects/blazing-ghoulish-graffiti/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/blazing-ghoulish-graffiti/loop.webp',
      introDuration: Duration(milliseconds: 2582),
    ),
    'blazing-ghoulish-graffiti': ProfileEffectConfig(
      id: 'blazing-ghoulish-graffiti',
      name: 'Blazing Graffiti',
      introUrl: 'https://media.katsklub.top/effects/blazing-ghoulish-graffiti/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/blazing-ghoulish-graffiti/loop.webp',
      introDuration: Duration(milliseconds: 2582),
    ),
    'bubble_tea_bliss': ProfileEffectConfig(
      id: 'bubble_tea_bliss',
      name: 'Bubble Tea Bliss',
      introUrl: 'https://media.katsklub.top/effects/bubble-tea-bliss/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/bubble-tea-bliss/loop.webp',
      introDuration: Duration(milliseconds: 4500),
    ),
    'bubble-tea-bliss': ProfileEffectConfig(
      id: 'bubble-tea-bliss',
      name: 'Bubble Tea Bliss',
      introUrl: 'https://media.katsklub.top/effects/bubble-tea-bliss/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/bubble-tea-bliss/loop.webp',
      introDuration: Duration(milliseconds: 4500),
    ),
    'bubblegum_zombie_slime': ProfileEffectConfig(
      id: 'bubblegum_zombie_slime',
      name: 'Bubblegum Slime',
      introUrl: 'https://media.katsklub.top/effects/bubblegum-zombie-slime/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/bubblegum-zombie-slime/loop.webp',
      introDuration: Duration(milliseconds: 2999),
    ),
    'bubblegum-zombie-slime': ProfileEffectConfig(
      id: 'bubblegum-zombie-slime',
      name: 'Bubblegum Slime',
      introUrl: 'https://media.katsklub.top/effects/bubblegum-zombie-slime/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/bubblegum-zombie-slime/loop.webp',
      introDuration: Duration(milliseconds: 2999),
    ),
    'chocolate_discord_os': ProfileEffectConfig(
      id: 'chocolate_discord_os',
      name: 'Chocolate OS',
      introUrl: 'https://media.katsklub.top/effects/chocolate-discord-os/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/chocolate-discord-os/loop.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'chocolate-discord-os': ProfileEffectConfig(
      id: 'chocolate-discord-os',
      name: 'Chocolate OS',
      introUrl: 'https://media.katsklub.top/effects/chocolate-discord-os/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/chocolate-discord-os/loop.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'classic_street_fighter': ProfileEffectConfig(
      id: 'classic_street_fighter',
      name: 'Classic Fighter',
      introUrl: 'https://media.katsklub.top/effects/classic-street-fighter/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/classic-street-fighter/loop.webp',
      introDuration: Duration(milliseconds: 3499),
    ),
    'classic-street-fighter': ProfileEffectConfig(
      id: 'classic-street-fighter',
      name: 'Classic Fighter',
      introUrl: 'https://media.katsklub.top/effects/classic-street-fighter/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/classic-street-fighter/loop.webp',
      introDuration: Duration(milliseconds: 3499),
    ),
    'clockwork_butterflies': ProfileEffectConfig(
      id: 'clockwork_butterflies',
      name: 'Clockwork Butterflies',
      introUrl: 'https://media.katsklub.top/effects/clockwork-butterflies/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/clockwork-butterflies/loop.webp',
      introDuration: Duration(milliseconds: 4800),
    ),
    'clockwork-butterflies': ProfileEffectConfig(
      id: 'clockwork-butterflies',
      name: 'Clockwork Butterflies',
      introUrl: 'https://media.katsklub.top/effects/clockwork-butterflies/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/clockwork-butterflies/loop.webp',
      introDuration: Duration(milliseconds: 4800),
    ),
    'cloud_zeppelin': ProfileEffectConfig(
      id: 'cloud_zeppelin',
      name: 'Cloud Zeppelin',
      introUrl: 'https://media.katsklub.top/effects/cloud-zeppelin/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/cloud-zeppelin/loop.webp',
      introDuration: Duration(milliseconds: 4800),
    ),
    'cloud-zeppelin': ProfileEffectConfig(
      id: 'cloud-zeppelin',
      name: 'Cloud Zeppelin',
      introUrl: 'https://media.katsklub.top/effects/cloud-zeppelin/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/cloud-zeppelin/loop.webp',
      introDuration: Duration(milliseconds: 4800),
    ),
    'deck_the_halls_aurora': ProfileEffectConfig(
      id: 'deck_the_halls_aurora',
      name: 'Deck the Halls Aurora',
      introUrl: 'https://media.katsklub.top/effects/deck-the-halls-aurora/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/deck-the-halls-aurora/loop.webp',
      introDuration: Duration(milliseconds: 1749),
    ),
    'deck-the-halls-aurora': ProfileEffectConfig(
      id: 'deck-the-halls-aurora',
      name: 'Deck the Halls Aurora',
      introUrl: 'https://media.katsklub.top/effects/deck-the-halls-aurora/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/deck-the-halls-aurora/loop.webp',
      introDuration: Duration(milliseconds: 1749),
    ),
    'deck_the_halls_dusk': ProfileEffectConfig(
      id: 'deck_the_halls_dusk',
      name: 'Deck the Halls Dusk',
      introUrl: 'https://media.katsklub.top/effects/deck-the-halls-dusk/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/deck-the-halls-dusk/loop.webp',
      introDuration: Duration(milliseconds: 1749),
    ),
    'deck-the-halls-dusk': ProfileEffectConfig(
      id: 'deck-the-halls-dusk',
      name: 'Deck the Halls Dusk',
      introUrl: 'https://media.katsklub.top/effects/deck-the-halls-dusk/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/deck-the-halls-dusk/loop.webp',
      introDuration: Duration(milliseconds: 1749),
    ),
    'deck_the_halls_ember': ProfileEffectConfig(
      id: 'deck_the_halls_ember',
      name: 'Deck the Halls Ember',
      introUrl: 'https://media.katsklub.top/effects/deck-the-halls-ember/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/deck-the-halls-ember/loop.webp',
      introDuration: Duration(milliseconds: 1749),
    ),
    'deck-the-halls-ember': ProfileEffectConfig(
      id: 'deck-the-halls-ember',
      name: 'Deck the Halls Ember',
      introUrl: 'https://media.katsklub.top/effects/deck-the-halls-ember/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/deck-the-halls-ember/loop.webp',
      introDuration: Duration(milliseconds: 1749),
    ),
    'deck_the_halls_mix': ProfileEffectConfig(
      id: 'deck_the_halls_mix',
      name: 'Deck the Halls Mix',
      introUrl: 'https://media.katsklub.top/effects/deck-the-halls-mix/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/deck-the-halls-mix/loop.webp',
      introDuration: Duration(milliseconds: 1749),
    ),
    'deck-the-halls-mix': ProfileEffectConfig(
      id: 'deck-the-halls-mix',
      name: 'Deck the Halls Mix',
      introUrl: 'https://media.katsklub.top/effects/deck-the-halls-mix/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/deck-the-halls-mix/loop.webp',
      introDuration: Duration(milliseconds: 1749),
    ),
    'ekko_s_aeroglider_stunts': ProfileEffectConfig(
      id: 'ekko_s_aeroglider_stunts',
      name: 'Ekko\'s Aeroglider',
      introUrl: 'https://media.katsklub.top/effects/ekko-s-aeroglider-stunts/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/ekko-s-aeroglider-stunts/loop.webp',
      introDuration: Duration(milliseconds: 3082),
    ),
    'ekko-s-aeroglider-stunts': ProfileEffectConfig(
      id: 'ekko-s-aeroglider-stunts',
      name: 'Ekko\'s Aeroglider',
      introUrl: 'https://media.katsklub.top/effects/ekko-s-aeroglider-stunts/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/ekko-s-aeroglider-stunts/loop.webp',
      introDuration: Duration(milliseconds: 3082),
    ),
    'enchanted_forest': ProfileEffectConfig(
      id: 'enchanted_forest',
      name: 'Enchanted Forest',
      introUrl: 'https://media.katsklub.top/effects/enchanted-forest/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/enchanted-forest/loop.webp',
      introDuration: Duration(milliseconds: 3082),
    ),
    'enchanted-forest': ProfileEffectConfig(
      id: 'enchanted-forest',
      name: 'Enchanted Forest',
      introUrl: 'https://media.katsklub.top/effects/enchanted-forest/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/enchanted-forest/loop.webp',
      introDuration: Duration(milliseconds: 3082),
    ),
    'flutter_and_frolic': ProfileEffectConfig(
      id: 'flutter_and_frolic',
      name: 'Flutter & Frolic',
      introUrl: 'https://media.katsklub.top/effects/flutter-and-frolic/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/flutter-and-frolic/loop.webp',
      introDuration: Duration(milliseconds: 3168),
    ),
    'flutter-and-frolic': ProfileEffectConfig(
      id: 'flutter-and-frolic',
      name: 'Flutter & Frolic',
      introUrl: 'https://media.katsklub.top/effects/flutter-and-frolic/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/flutter-and-frolic/loop.webp',
      introDuration: Duration(milliseconds: 3168),
    ),
    'fog_of_war': ProfileEffectConfig(
      id: 'fog_of_war',
      name: 'Fog of War',
      introUrl: 'https://media.katsklub.top/effects/fog-of-war/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/fog-of-war/loop.webp',
      introDuration: Duration(milliseconds: 4332),
    ),
    'fog-of-war': ProfileEffectConfig(
      id: 'fog-of-war',
      name: 'Fog of War',
      introUrl: 'https://media.katsklub.top/effects/fog-of-war/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/fog-of-war/loop.webp',
      introDuration: Duration(milliseconds: 4332),
    ),
    'heartzilla_purple': ProfileEffectConfig(
      id: 'heartzilla_purple',
      name: 'Heartzilla Purple',
      introUrl: 'https://media.katsklub.top/effects/heartzilla-purple/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/heartzilla-purple/loop.webp',
      introDuration: Duration(milliseconds: 3600),
    ),
    'heartzilla-purple': ProfileEffectConfig(
      id: 'heartzilla-purple',
      name: 'Heartzilla Purple',
      introUrl: 'https://media.katsklub.top/effects/heartzilla-purple/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/heartzilla-purple/loop.webp',
      introDuration: Duration(milliseconds: 3600),
    ),
    'infernal_dark_omens': ProfileEffectConfig(
      id: 'infernal_dark_omens',
      name: 'Infernal Omens',
      introUrl: 'https://media.katsklub.top/effects/infernal-dark-omens/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/infernal-dark-omens/loop.webp',
      introDuration: Duration(milliseconds: 2999),
    ),
    'infernal-dark-omens': ProfileEffectConfig(
      id: 'infernal-dark-omens',
      name: 'Infernal Omens',
      introUrl: 'https://media.katsklub.top/effects/infernal-dark-omens/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/infernal-dark-omens/loop.webp',
      introDuration: Duration(milliseconds: 2999),
    ),
    'innovator_s_masterwork': ProfileEffectConfig(
      id: 'innovator_s_masterwork',
      name: 'Innovator\'s Masterwork',
      introUrl: 'https://media.katsklub.top/effects/innovator-s-masterwork/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/innovator-s-masterwork/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'innovator-s-masterwork': ProfileEffectConfig(
      id: 'innovator-s-masterwork',
      name: 'Innovator\'s Masterwork',
      introUrl: 'https://media.katsklub.top/effects/innovator-s-masterwork/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/innovator-s-masterwork/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'jinx_and_pow_pow': ProfileEffectConfig(
      id: 'jinx_and_pow_pow',
      name: 'Jinx & Pow-Pow',
      introUrl: 'https://media.katsklub.top/effects/jinx-and-pow-pow/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/jinx-and-pow-pow/loop.webp',
      introDuration: Duration(milliseconds: 4333),
    ),
    'jinx-and-pow-pow': ProfileEffectConfig(
      id: 'jinx-and-pow-pow',
      name: 'Jinx & Pow-Pow',
      introUrl: 'https://media.katsklub.top/effects/jinx-and-pow-pow/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/jinx-and-pow-pow/loop.webp',
      introDuration: Duration(milliseconds: 4333),
    ),
    'kawaii_mode': ProfileEffectConfig(
      id: 'kawaii_mode',
      name: 'Kawaii Mode',
      introUrl: 'https://media.katsklub.top/effects/kawaii-mode/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/kawaii-mode/loop.webp',
      introDuration: Duration(milliseconds: 4374),
    ),
    'kawaii-mode': ProfileEffectConfig(
      id: 'kawaii-mode',
      name: 'Kawaii Mode',
      introUrl: 'https://media.katsklub.top/effects/kawaii-mode/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/kawaii-mode/loop.webp',
      introDuration: Duration(milliseconds: 4374),
    ),
    'koi_garden': ProfileEffectConfig(
      id: 'koi_garden',
      name: 'Koi Garden',
      introUrl: 'https://media.katsklub.top/effects/koi-garden/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/koi-garden/loop.webp',
      introDuration: Duration(milliseconds: 3666),
    ),
    'koi-garden': ProfileEffectConfig(
      id: 'koi-garden',
      name: 'Koi Garden',
      introUrl: 'https://media.katsklub.top/effects/koi-garden/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/koi-garden/loop.webp',
      introDuration: Duration(milliseconds: 3666),
    ),
    'lofi_cat_zoomies_festive': ProfileEffectConfig(
      id: 'lofi_cat_zoomies_festive',
      name: 'Festive Cat Zoomies',
      introUrl: 'https://media.katsklub.top/effects/lofi-cat-zoomies-festive/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/lofi-cat-zoomies-festive/loop.webp',
      introDuration: Duration(milliseconds: 4996),
    ),
    'lofi-cat-zoomies-festive': ProfileEffectConfig(
      id: 'lofi-cat-zoomies-festive',
      name: 'Festive Cat Zoomies',
      introUrl: 'https://media.katsklub.top/effects/lofi-cat-zoomies-festive/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/lofi-cat-zoomies-festive/loop.webp',
      introDuration: Duration(milliseconds: 4996),
    ),
    'lofi_girl_snow_angel': ProfileEffectConfig(
      id: 'lofi_girl_snow_angel',
      name: 'Snow Angel Lofi',
      introUrl: 'https://media.katsklub.top/effects/lofi-girl-snow-angel/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/lofi-girl-snow-angel/loop.webp',
      introDuration: Duration(milliseconds: 5007),
    ),
    'lofi-girl-snow-angel': ProfileEffectConfig(
      id: 'lofi-girl-snow-angel',
      name: 'Snow Angel Lofi',
      introUrl: 'https://media.katsklub.top/effects/lofi-girl-snow-angel/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/lofi-girl-snow-angel/loop.webp',
      introDuration: Duration(milliseconds: 5007),
    ),
    'lofi_girl_study_break': ProfileEffectConfig(
      id: 'lofi_girl_study_break',
      name: 'Study Break Lofi',
      introUrl: 'https://media.katsklub.top/effects/lofi-girl-study-break/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/lofi-girl-study-break/loop.webp',
      introDuration: Duration(milliseconds: 4999),
    ),
    'lofi-girl-study-break': ProfileEffectConfig(
      id: 'lofi-girl-study-break',
      name: 'Study Break Lofi',
      introUrl: 'https://media.katsklub.top/effects/lofi-girl-study-break/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/lofi-girl-study-break/loop.webp',
      introDuration: Duration(milliseconds: 4999),
    ),
    'm_bison_s_return': ProfileEffectConfig(
      id: 'm_bison_s_return',
      name: 'M. Bison\'s Return',
      introUrl: 'https://media.katsklub.top/effects/m-bison-s-return/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/m-bison-s-return/loop.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'm-bison-s-return': ProfileEffectConfig(
      id: 'm-bison-s-return',
      name: 'M. Bison\'s Return',
      introUrl: 'https://media.katsklub.top/effects/m-bison-s-return/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/m-bison-s-return/loop.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'mermaid_whisperer': ProfileEffectConfig(
      id: 'mermaid_whisperer',
      name: 'Mermaid Whisperer',
      introUrl: 'https://media.katsklub.top/effects/mermaid-whisperer/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/mermaid-whisperer/loop.webp',
      introDuration: Duration(milliseconds: 4252),
    ),
    'mermaid-whisperer': ProfileEffectConfig(
      id: 'mermaid-whisperer',
      name: 'Mermaid Whisperer',
      introUrl: 'https://media.katsklub.top/effects/mermaid-whisperer/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/mermaid-whisperer/loop.webp',
      introDuration: Duration(milliseconds: 4252),
    ),
    'midnight_dark_omens': ProfileEffectConfig(
      id: 'midnight_dark_omens',
      name: 'Midnight Omens',
      introUrl: 'https://media.katsklub.top/effects/midnight-dark-omens/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/midnight-dark-omens/loop.webp',
      introDuration: Duration(milliseconds: 2999),
    ),
    'midnight-dark-omens': ProfileEffectConfig(
      id: 'midnight-dark-omens',
      name: 'Midnight Omens',
      introUrl: 'https://media.katsklub.top/effects/midnight-dark-omens/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/midnight-dark-omens/loop.webp',
      introDuration: Duration(milliseconds: 2999),
    ),
    'midnight_zombie_slime': ProfileEffectConfig(
      id: 'midnight_zombie_slime',
      name: 'Midnight Slime',
      introUrl: 'https://media.katsklub.top/effects/midnight-zombie-slime/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/midnight-zombie-slime/loop.webp',
      introDuration: Duration(milliseconds: 2999),
    ),
    'midnight-zombie-slime': ProfileEffectConfig(
      id: 'midnight-zombie-slime',
      name: 'Midnight Slime',
      introUrl: 'https://media.katsklub.top/effects/midnight-zombie-slime/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/midnight-zombie-slime/loop.webp',
      introDuration: Duration(milliseconds: 2999),
    ),
    'mimic': ProfileEffectConfig(
      id: 'mimic',
      name: 'Mimic Chest',
      introUrl: 'https://media.katsklub.top/effects/mimic/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/mimic/loop.webp',
      introDuration: Duration(milliseconds: 2999),
    ),
    'mooncap_forest_blue': ProfileEffectConfig(
      id: 'mooncap_forest_blue',
      name: 'Mooncap Forest Blue',
      introUrl: 'https://media.katsklub.top/effects/mooncap-forest-blue/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/mooncap-forest-blue/loop.webp',
      introDuration: Duration(milliseconds: 3082),
    ),
    'mooncap-forest-blue': ProfileEffectConfig(
      id: 'mooncap-forest-blue',
      name: 'Mooncap Forest Blue',
      introUrl: 'https://media.katsklub.top/effects/mooncap-forest-blue/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/mooncap-forest-blue/loop.webp',
      introDuration: Duration(milliseconds: 3082),
    ),
    'mooncap_forest_pink': ProfileEffectConfig(
      id: 'mooncap_forest_pink',
      name: 'Mooncap Forest Pink',
      introUrl: 'https://media.katsklub.top/effects/mooncap-forest-pink/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/mooncap-forest-pink/loop.webp',
      introDuration: Duration(milliseconds: 3082),
    ),
    'mooncap-forest-pink': ProfileEffectConfig(
      id: 'mooncap-forest-pink',
      name: 'Mooncap Forest Pink',
      introUrl: 'https://media.katsklub.top/effects/mooncap-forest-pink/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/mooncap-forest-pink/loop.webp',
      introDuration: Duration(milliseconds: 3082),
    ),
    'neon_ghoulish_graffiti': ProfileEffectConfig(
      id: 'neon_ghoulish_graffiti',
      name: 'Neon Graffiti',
      introUrl: 'https://media.katsklub.top/effects/neon-ghoulish-graffiti/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/neon-ghoulish-graffiti/loop.webp',
      introDuration: Duration(milliseconds: 2582),
    ),
    'neon-ghoulish-graffiti': ProfileEffectConfig(
      id: 'neon-ghoulish-graffiti',
      name: 'Neon Graffiti',
      introUrl: 'https://media.katsklub.top/effects/neon-ghoulish-graffiti/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/neon-ghoulish-graffiti/loop.webp',
      introDuration: Duration(milliseconds: 2582),
    ),
    'ocean_flowers': ProfileEffectConfig(
      id: 'ocean_flowers',
      name: 'Ocean Flowers',
      introUrl: 'https://media.katsklub.top/effects/ocean-flowers/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/ocean-flowers/loop.webp',
      introDuration: Duration(milliseconds: 3832),
    ),
    'ocean-flowers': ProfileEffectConfig(
      id: 'ocean-flowers',
      name: 'Ocean Flowers',
      introUrl: 'https://media.katsklub.top/effects/ocean-flowers/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/ocean-flowers/loop.webp',
      introDuration: Duration(milliseconds: 3832),
    ),
    'of_ink_and_steel': ProfileEffectConfig(
      id: 'of_ink_and_steel',
      name: 'Of Ink & Steel',
      introUrl: 'https://media.katsklub.top/effects/of-ink-and-steel/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/of-ink-and-steel/loop.webp',
      introDuration: Duration(milliseconds: 3923),
    ),
    'of-ink-and-steel': ProfileEffectConfig(
      id: 'of-ink-and-steel',
      name: 'Of Ink & Steel',
      introUrl: 'https://media.katsklub.top/effects/of-ink-and-steel/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/of-ink-and-steel/loop.webp',
      introDuration: Duration(milliseconds: 3923),
    ),
    'oni_s_curse': ProfileEffectConfig(
      id: 'oni_s_curse',
      name: 'Oni\'s Curse',
      introUrl: 'https://media.katsklub.top/effects/oni-s-curse/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/oni-s-curse/loop.webp',
      introDuration: Duration(milliseconds: 2916),
    ),
    'oni-s-curse': ProfileEffectConfig(
      id: 'oni-s-curse',
      name: 'Oni\'s Curse',
      introUrl: 'https://media.katsklub.top/effects/oni-s-curse/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/oni-s-curse/loop.webp',
      introDuration: Duration(milliseconds: 2916),
    ),
    'paint_the_town_blue': ProfileEffectConfig(
      id: 'paint_the_town_blue',
      name: 'Paint The Town Blue',
      introUrl: 'https://media.katsklub.top/effects/paint-the-town-blue/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/paint-the-town-blue/loop.webp',
      introDuration: Duration(milliseconds: 3916),
    ),
    'paint-the-town-blue': ProfileEffectConfig(
      id: 'paint-the-town-blue',
      name: 'Paint The Town Blue',
      introUrl: 'https://media.katsklub.top/effects/paint-the-town-blue/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/paint-the-town-blue/loop.webp',
      introDuration: Duration(milliseconds: 3916),
    ),
    'penguins_on_ice': ProfileEffectConfig(
      id: 'penguins_on_ice',
      name: 'Penguins on Ice',
      introUrl: 'https://media.katsklub.top/effects/penguins-on-ice/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/penguins-on-ice/loop.webp',
      introDuration: Duration(milliseconds: 4999),
    ),
    'penguins-on-ice': ProfileEffectConfig(
      id: 'penguins-on-ice',
      name: 'Penguins on Ice',
      introUrl: 'https://media.katsklub.top/effects/penguins-on-ice/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/penguins-on-ice/loop.webp',
      introDuration: Duration(milliseconds: 4999),
    ),
    'plankton_splat': ProfileEffectConfig(
      id: 'plankton_splat',
      name: 'Plankton Splat',
      introUrl: 'https://media.katsklub.top/effects/plankton-splat/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/plankton-splat/loop.webp',
      introDuration: Duration(milliseconds: 4291),
    ),
    'plankton-splat': ProfileEffectConfig(
      id: 'plankton-splat',
      name: 'Plankton Splat',
      introUrl: 'https://media.katsklub.top/effects/plankton-splat/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/plankton-splat/loop.webp',
      introDuration: Duration(milliseconds: 4291),
    ),
    'plushie_party': ProfileEffectConfig(
      id: 'plushie_party',
      name: 'Plushie Party',
      introUrl: 'https://media.katsklub.top/effects/plushie-party/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/plushie-party/loop.webp',
      introDuration: Duration(milliseconds: 3420),
    ),
    'plushie-party': ProfileEffectConfig(
      id: 'plushie-party',
      name: 'Plushie Party',
      introUrl: 'https://media.katsklub.top/effects/plushie-party/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/plushie-party/loop.webp',
      introDuration: Duration(milliseconds: 3420),
    ),
    'portal_beyond_blue': ProfileEffectConfig(
      id: 'portal_beyond_blue',
      name: 'Portal Beyond Blue',
      introUrl: 'https://media.katsklub.top/effects/portal-beyond-blue/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/portal-beyond-blue/loop.webp',
      introDuration: Duration(milliseconds: 3920),
    ),
    'portal-beyond-blue': ProfileEffectConfig(
      id: 'portal-beyond-blue',
      name: 'Portal Beyond Blue',
      introUrl: 'https://media.katsklub.top/effects/portal-beyond-blue/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/portal-beyond-blue/loop.webp',
      introDuration: Duration(milliseconds: 3920),
    ),
    'portal_beyond_purple': ProfileEffectConfig(
      id: 'portal_beyond_purple',
      name: 'Portal Beyond Purple',
      introUrl: 'https://media.katsklub.top/effects/portal-beyond-purple/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/portal-beyond-purple/loop.webp',
      introDuration: Duration(milliseconds: 3920),
    ),
    'portal-beyond-purple': ProfileEffectConfig(
      id: 'portal-beyond-purple',
      name: 'Portal Beyond Purple',
      introUrl: 'https://media.katsklub.top/effects/portal-beyond-purple/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/portal-beyond-purple/loop.webp',
      introDuration: Duration(milliseconds: 3920),
    ),
    'red_dragon': ProfileEffectConfig(
      id: 'red_dragon',
      name: 'Red Dragon',
      introUrl: 'https://media.katsklub.top/effects/red-dragon/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/red-dragon/loop.webp',
      introDuration: Duration(milliseconds: 3499),
    ),
    'red-dragon': ProfileEffectConfig(
      id: 'red-dragon',
      name: 'Red Dragon',
      introUrl: 'https://media.katsklub.top/effects/red-dragon/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/red-dragon/loop.webp',
      introDuration: Duration(milliseconds: 3499),
    ),
    'sakura_katana': ProfileEffectConfig(
      id: 'sakura_katana',
      name: 'Sakura Katana',
      introUrl: 'https://media.katsklub.top/effects/sakura-katana/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/sakura-katana/loop.webp',
      introDuration: Duration(milliseconds: 2416),
    ),
    'sakura-katana': ProfileEffectConfig(
      id: 'sakura-katana',
      name: 'Sakura Katana',
      introUrl: 'https://media.katsklub.top/effects/sakura-katana/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/sakura-katana/loop.webp',
      introDuration: Duration(milliseconds: 2416),
    ),
    'scarlet_fall_foliage': ProfileEffectConfig(
      id: 'scarlet_fall_foliage',
      name: 'Scarlet Foliage',
      introUrl: 'https://media.katsklub.top/effects/scarlet-fall-foliage/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/scarlet-fall-foliage/loop.webp',
      introDuration: Duration(milliseconds: 2960),
    ),
    'scarlet-fall-foliage': ProfileEffectConfig(
      id: 'scarlet-fall-foliage',
      name: 'Scarlet Foliage',
      introUrl: 'https://media.katsklub.top/effects/scarlet-fall-foliage/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/scarlet-fall-foliage/loop.webp',
      introDuration: Duration(milliseconds: 2960),
    ),
    'snowy_shenanigans_giddy': ProfileEffectConfig(
      id: 'snowy_shenanigans_giddy',
      name: 'Snowy Giddy',
      introUrl: 'https://media.katsklub.top/effects/snowy-shenanigans-giddy/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/snowy-shenanigans-giddy/loop.webp',
      introDuration: Duration(milliseconds: 4166),
    ),
    'snowy-shenanigans-giddy': ProfileEffectConfig(
      id: 'snowy-shenanigans-giddy',
      name: 'Snowy Giddy',
      introUrl: 'https://media.katsklub.top/effects/snowy-shenanigans-giddy/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/snowy-shenanigans-giddy/loop.webp',
      introDuration: Duration(milliseconds: 4166),
    ),
    'snowy_shenanigans_jolly': ProfileEffectConfig(
      id: 'snowy_shenanigans_jolly',
      name: 'Snowy Jolly',
      introUrl: 'https://media.katsklub.top/effects/snowy-shenanigans-jolly/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/snowy-shenanigans-jolly/loop.webp',
      introDuration: Duration(milliseconds: 4166),
    ),
    'snowy-shenanigans-jolly': ProfileEffectConfig(
      id: 'snowy-shenanigans-jolly',
      name: 'Snowy Jolly',
      introUrl: 'https://media.katsklub.top/effects/snowy-shenanigans-jolly/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/snowy-shenanigans-jolly/loop.webp',
      introDuration: Duration(milliseconds: 4166),
    ),
    'snowy_shenanigans_smooch': ProfileEffectConfig(
      id: 'snowy_shenanigans_smooch',
      name: 'Snowy Smooch',
      introUrl: 'https://media.katsklub.top/effects/snowy-shenanigans-smooch/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/snowy-shenanigans-smooch/loop.webp',
      introDuration: Duration(milliseconds: 4166),
    ),
    'snowy-shenanigans-smooch': ProfileEffectConfig(
      id: 'snowy-shenanigans-smooch',
      name: 'Snowy Smooch',
      introUrl: 'https://media.katsklub.top/effects/snowy-shenanigans-smooch/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/snowy-shenanigans-smooch/loop.webp',
      introDuration: Duration(milliseconds: 4166),
    ),
    'snowy_shenanigans_suave': ProfileEffectConfig(
      id: 'snowy_shenanigans_suave',
      name: 'Snowy Suave',
      introUrl: 'https://media.katsklub.top/effects/snowy-shenanigans-suave/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/snowy-shenanigans-suave/loop.webp',
      introDuration: Duration(milliseconds: 4166),
    ),
    'snowy-shenanigans-suave': ProfileEffectConfig(
      id: 'snowy-shenanigans-suave',
      name: 'Snowy Suave',
      introUrl: 'https://media.katsklub.top/effects/snowy-shenanigans-suave/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/snowy-shenanigans-suave/loop.webp',
      introDuration: Duration(milliseconds: 4166),
    ),
    'spirit_of_the_kitsune': ProfileEffectConfig(
      id: 'spirit_of_the_kitsune',
      name: 'Spirit of the Kitsune',
      introUrl: 'https://media.katsklub.top/effects/spirit-of-the-kitsune/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/spirit-of-the-kitsune/loop.webp',
      introDuration: Duration(milliseconds: 6666),
    ),
    'spirit-of-the-kitsune': ProfileEffectConfig(
      id: 'spirit-of-the-kitsune',
      name: 'Spirit of the Kitsune',
      introUrl: 'https://media.katsklub.top/effects/spirit-of-the-kitsune/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/spirit-of-the-kitsune/loop.webp',
      introDuration: Duration(milliseconds: 6666),
    ),
    'street_fighter_6': ProfileEffectConfig(
      id: 'street_fighter_6',
      name: 'Street Fighter 6',
      introUrl: 'https://media.katsklub.top/effects/street-fighter-6/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/street-fighter-6/loop.webp',
      introDuration: Duration(milliseconds: 3999),
    ),
    'street-fighter-6': ProfileEffectConfig(
      id: 'street-fighter-6',
      name: 'Street Fighter 6',
      introUrl: 'https://media.katsklub.top/effects/street-fighter-6/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/street-fighter-6/loop.webp',
      introDuration: Duration(milliseconds: 3999),
    ),
    'sun_and_moon': ProfileEffectConfig(
      id: 'sun_and_moon',
      name: 'Sun & Moon',
      introUrl: 'https://media.katsklub.top/effects/sun-and-moon/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/sun-and-moon/loop.webp',
      introDuration: Duration(milliseconds: 4320),
    ),
    'sun-and-moon': ProfileEffectConfig(
      id: 'sun-and-moon',
      name: 'Sun & Moon',
      introUrl: 'https://media.katsklub.top/effects/sun-and-moon/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/sun-and-moon/loop.webp',
      introDuration: Duration(milliseconds: 4320),
    ),
    'sunrise_grove': ProfileEffectConfig(
      id: 'sunrise_grove',
      name: 'Sunrise Grove',
      introUrl: 'https://media.katsklub.top/effects/sunrise-grove/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/sunrise-grove/loop.webp',
      introDuration: Duration(milliseconds: 2960),
    ),
    'sunrise-grove': ProfileEffectConfig(
      id: 'sunrise-grove',
      name: 'Sunrise Grove',
      introUrl: 'https://media.katsklub.top/effects/sunrise-grove/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/sunrise-grove/loop.webp',
      introDuration: Duration(milliseconds: 2960),
    ),
    'twilight_grove': ProfileEffectConfig(
      id: 'twilight_grove',
      name: 'Twilight Grove',
      introUrl: 'https://media.katsklub.top/effects/twilight-grove/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/twilight-grove/loop.webp',
      introDuration: Duration(milliseconds: 2960),
    ),
    'twilight-grove': ProfileEffectConfig(
      id: 'twilight-grove',
      name: 'Twilight Grove',
      introUrl: 'https://media.katsklub.top/effects/twilight-grove/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/twilight-grove/loop.webp',
      introDuration: Duration(milliseconds: 2960),
    ),
    'twist_of_luck': ProfileEffectConfig(
      id: 'twist_of_luck',
      name: 'Twist of Luck',
      introUrl: 'https://media.katsklub.top/effects/twist-of-luck/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/twist-of-luck/loop.webp',
      introDuration: Duration(milliseconds: 5000),
    ),
    'twist-of-luck': ProfileEffectConfig(
      id: 'twist-of-luck',
      name: 'Twist of Luck',
      introUrl: 'https://media.katsklub.top/effects/twist-of-luck/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/twist-of-luck/loop.webp',
      introDuration: Duration(milliseconds: 5000),
    ),
    'vct_supernova': ProfileEffectConfig(
      id: 'vct_supernova',
      name: 'VCT Champions Supernova',
      introUrl: 'https://media.katsklub.top/effects/vct-supernova/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/vct-supernova/loop.webp',
      introDuration: Duration(milliseconds: 4480),
    ),
    'vct-supernova': ProfileEffectConfig(
      id: 'vct-supernova',
      name: 'VCT Champions Supernova',
      introUrl: 'https://media.katsklub.top/effects/vct-supernova/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/vct-supernova/loop.webp',
      introDuration: Duration(milliseconds: 4480),
    ),
    'wonder_construction': ProfileEffectConfig(
      id: 'wonder_construction',
      name: 'Wonder Construction',
      introUrl: 'https://media.katsklub.top/effects/wonder-construction/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/wonder-construction/loop.webp',
      introDuration: Duration(milliseconds: 4916),
    ),
    'wonder-construction': ProfileEffectConfig(
      id: 'wonder-construction',
      name: 'Wonder Construction',
      introUrl: 'https://media.katsklub.top/effects/wonder-construction/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/wonder-construction/loop.webp',
      introDuration: Duration(milliseconds: 4916),
    ),
    'woodland_fall_foliage': ProfileEffectConfig(
      id: 'woodland_fall_foliage',
      name: 'Woodland Foliage',
      introUrl: 'https://media.katsklub.top/effects/woodland-fall-foliage/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/woodland-fall-foliage/loop.webp',
      introDuration: Duration(milliseconds: 2960),
    ),
    'woodland-fall-foliage': ProfileEffectConfig(
      id: 'woodland-fall-foliage',
      name: 'Woodland Foliage',
      introUrl: 'https://media.katsklub.top/effects/woodland-fall-foliage/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/woodland-fall-foliage/loop.webp',
      introDuration: Duration(milliseconds: 2960),
    ),
    'yoru_dimensional_rip': ProfileEffectConfig(
      id: 'yoru_dimensional_rip',
      name: 'Yoru\'s Drift',
      introUrl: 'https://media.katsklub.top/effects/yoru-dimensional-rip/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/yoru-dimensional-rip/loop.webp',
      introDuration: Duration(milliseconds: 3923),
    ),
    'yoru-dimensional-rip': ProfileEffectConfig(
      id: 'yoru-dimensional-rip',
      name: 'Yoru\'s Drift',
      introUrl: 'https://media.katsklub.top/effects/yoru-dimensional-rip/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/yoru-dimensional-rip/loop.webp',
      introDuration: Duration(milliseconds: 3923),
    ),
  };

  static final Map<String, ProfileEffectConfig> _dynamicRegistry = {};
  static const String _cacheKey = 'katsklub_cached_profile_effects';

  /// Loads cached profile effects from persistent local storage on app start
  static Future<void> initFromLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_cacheKey);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(cachedJson);
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            registerFromMap(item);
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading cached profile effects: $e');
    }
  }

  /// Persists a list of effects from backend API to local cache and memory registry
  static Future<void> saveToLocalCache(List<Map<String, dynamic>> effectsList) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(effectsList));
      for (final item in effectsList) {
        registerFromMap(item);
      }
    } catch (e) {
      debugPrint('Error saving cached profile effects: $e');
    }
  }

  /// Non-blocking background sync with backend /api/effects
  static Future<void> syncWithBackend() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.apiBaseUrl}${ApiConfig.effectsPath}'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['ok'] == true && data['effects'] is List) {
          final List<Map<String, dynamic>> list =
              List<Map<String, dynamic>>.from(data['effects']);
          await saveToLocalCache(list);
        }
      }
    } catch (_) {}
  }

  /// Dynamically register or override an effect configuration (e.g. from backend API).
  static void register(ProfileEffectConfig config) {
    final key = config.id.toLowerCase();
    _dynamicRegistry[key] = config;
    final hyphenated = key.replaceAll('_', '-');
    _dynamicRegistry[hyphenated] = config;
    final underscored = key.replaceAll('-', '_');
    _dynamicRegistry[underscored] = config;
    final noSep = key.replaceAll('_', '').replaceAll('-', '');
    _dynamicRegistry[noSep] = config;
  }

  /// Registers an effect directly from an API map
  static void registerFromMap(Map<String, dynamic> data) {
    final key = data['key']?.toString().trim();
    if (key == null || key.isEmpty) return;
    final introUrl = data['introUrl']?.toString() ?? data['intro_url']?.toString();
    final loopUrl = data['loopUrl']?.toString() ?? data['loop_url']?.toString();
    if (introUrl == null || loopUrl == null) return;

    final existing = registry[key] ?? registry[key.replaceAll('_', '-')];
    final duration = existing != null
        ? existing.introDuration
        : Duration(milliseconds: (data['introDurationMs'] as num?)?.toInt() ?? 3000);

    register(ProfileEffectConfig(
      id: key,
      name: data['name']?.toString() ?? key,
      introUrl: introUrl,
      loopUrl: loopUrl,
      introDuration: duration,
    ));
  }

  /// Resolves an effect key or URL to a ProfileEffectConfig
  static ProfileEffectConfig? resolve(String? effectKey) {
    if (effectKey == null || effectKey.trim().isEmpty || effectKey == 'none') {
      return null;
    }
    final key = effectKey.trim().toLowerCase();
    if (_dynamicRegistry.containsKey(key)) {
      return _dynamicRegistry[key];
    }
    if (registry.containsKey(key)) {
      return registry[key];
    }
    final underscoreKey = key.replaceAll('-', '_');
    if (_dynamicRegistry.containsKey(underscoreKey)) {
      return _dynamicRegistry[underscoreKey];
    }
    if (registry.containsKey(underscoreKey)) {
      return registry[underscoreKey];
    }
    final hyphenKey = key.replaceAll('_', '-');
    if (_dynamicRegistry.containsKey(hyphenKey)) {
      return _dynamicRegistry[hyphenKey];
    }
    if (registry.containsKey(hyphenKey)) {
      return registry[hyphenKey];
    }
    final noSep = key.replaceAll('_', '').replaceAll('-', '');
    if (_dynamicRegistry.containsKey(noSep)) {
      return _dynamicRegistry[noSep];
    }
    // If it's a direct URL to a WebP
    if (effectKey.startsWith('http://') || effectKey.startsWith('https://')) {
      return ProfileEffectConfig(
        id: effectKey,
        name: 'Custom Effect',
        introUrl: effectKey,
        loopUrl: effectKey,
        introDuration: Duration.zero,
      );
    }

    // Convention Fallback:
    // If an effect exists in the DB or CDN but is not yet cached or compiled into this APK build,
    // synthesize standard R2 CDN URLs so the profile NEVER renders plain or empty!
    final slug = key.replaceAll('_', '-');
    final formattedName = key
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');

    return ProfileEffectConfig(
      id: key,
      name: formattedName.isEmpty ? 'Profile Effect' : formattedName,
      introUrl: 'https://media.katsklub.top/effects/$slug/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/$slug/loop.webp',
      introDuration: const Duration(milliseconds: 3000),
    );
  }
}

/// A high-performance, non-intrusive animated profile effect overlay.
///
/// Features:
/// - Reliable intro detection via Flutter's built-in [Image.frameBuilder].
///   The countdown starts strictly when the first frame actually renders on screen,
///   guaranteeing the user always experiences the full intro animation.
/// - Seamless cross-fade transition from intro to ambient idle loop.
/// - Automatically unmounts intro image after fade-out to free GPU texture memory.
/// - Zero-jank performance: Pauses completely when scrolled offscreen ([isActive] = false).
/// - No heavy GPU [ShaderMask] `saveLayer` calls; maintains 60/120 FPS buttery-smooth scrolling.
/// - Wrapped in [IgnorePointer] so all profile buttons, avatar, cover, and links remain 100% interactive.
class ProfileEffectWidget extends StatefulWidget {
  const ProfileEffectWidget({
    required this.effect,
    this.height,
    this.applyBottomFade = false,
    this.isActive = true,
    super.key,
  });

  final String effect;
  final double? height;
  final bool applyBottomFade;
  final bool isActive;

  @override
  State<ProfileEffectWidget> createState() => _ProfileEffectWidgetState();
}

class _ProfileEffectWidgetState extends State<ProfileEffectWidget> {
  ProfileEffectConfig? _config;
  bool _introTimerStarted = false;
  bool _introFadeOut = false;
  bool _introDone = false;

  Timer? _introTimer;
  Timer? _safetyTimeout;
  CachedNetworkImageProvider? _introProvider;
  CachedNetworkImageProvider? _loopProvider;

  @override
  void initState() {
    super.initState();
    _setupEffect();
  }

  @override
  void didUpdateWidget(ProfileEffectWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.effect != widget.effect) {
      _cleanupTimers();
      _setupEffect();
    } else if (!oldWidget.isActive && widget.isActive) {
      // Resumed from offscreen: ensure providers are warm
      _warmProviders();
    }
  }

  void _cleanupTimers() {
    _introTimer?.cancel();
    _introTimer = null;
    _safetyTimeout?.cancel();
    _safetyTimeout = null;
  }

  void _warmProviders() {
    final config = _config;
    if (config == null) return;
    _loopProvider ??= CachedNetworkImageProvider(config.loopUrl);
    if (config.introDuration > Duration.zero && config.introUrl != config.loopUrl && !_introDone) {
      _introProvider ??= CachedNetworkImageProvider(config.introUrl);
    }
  }

  void _setupEffect() {
    _cleanupTimers();
    _config = ProfileEffectConfig.resolve(widget.effect);

    if (_config == null) {
      _introDone = true;
      return;
    }

    final config = _config!;
    _loopProvider = CachedNetworkImageProvider(config.loopUrl);

    if (config.introDuration > Duration.zero && config.introUrl != config.loopUrl) {
      _introProvider = CachedNetworkImageProvider(config.introUrl);
      _introDone = false;
      _introFadeOut = false;
      _introTimerStarted = false;

      // Safety timeout: If intro fails to render first frame within 12s, fall back to loop directly
      _safetyTimeout = Timer(const Duration(milliseconds: 12000), () {
        if (!mounted) return;
        if (!_introTimerStarted && !_introDone) {
          setState(() {
            _introDone = true;
          });
        }
      });
    } else {
      _introProvider = null;
      _introDone = true;
      _introFadeOut = false;
      _introTimerStarted = false;
    }
  }

  void _startIntroCountdown() {
    if (_introTimerStarted || _introDone) return;
    _introTimerStarted = true;
    _safetyTimeout?.cancel();

    final config = _config;
    if (config == null) return;

    _introTimer?.cancel();
    _introTimer = Timer(config.introDuration, () {
      if (!mounted) return;
      setState(() {
        _introFadeOut = true;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Precache loop into Flutter's image cache
    if (_loopProvider != null) {
      precacheImage(_loopProvider!, context).catchError((_) {});
    }
    // Pre-fetch raw intro file to disk cache WITHOUT starting the animation stream ticker.
    // NOTE: Do NOT use precacheImage on the animated intro; precacheImage attaches a stream listener
    // which immediately starts advancing animation frames in the background before the widget paints,
    // causing it to skip frame 0!
    final config = _config;
    if (config != null &&
        config.introDuration > Duration.zero &&
        config.introUrl != config.loopUrl &&
        !_introDone) {
      unawaited(
        DefaultCacheManager()
            .getSingleFile(config.introUrl)
            .then((_) {}, onError: (_) {}),
      );
    }
  }

  @override
  void dispose() {
    _cleanupTimers();
    _introProvider?.evict();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // When scrolled offscreen, unmount images completely to pause decode loop and eliminate GPU raster load
    if (!widget.isActive) {
      return const SizedBox.shrink();
    }

    final config = _config;
    if (config == null) {
      return const SizedBox.shrink();
    }

    final double effectiveHeight = widget.height ?? 460.h;
    final bool hasIntro = !_introDone && _introProvider != null;

    final Widget effectContent = SizedBox(
      width: double.infinity,
      height: effectiveHeight,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          // Layer 1: Ambient Idle Loop (direct zero-overhead Image once intro is done; smooth fade-in if cross-fading)
          if (!hasIntro)
            Image(
              image: _loopProvider ?? CachedNetworkImageProvider(config.loopUrl),
              width: double.infinity,
              height: effectiveHeight,
              fit: BoxFit.fitWidth,
              alignment: Alignment.topCenter,
              filterQuality: FilterQuality.low,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            )
          else if (_introFadeOut)
            AnimatedOpacity(
              opacity: 1.0,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
              child: Image(
                image: _loopProvider ?? CachedNetworkImageProvider(config.loopUrl),
                width: double.infinity,
                height: effectiveHeight,
                fit: BoxFit.fitWidth,
                alignment: Alignment.topCenter,
                filterQuality: FilterQuality.low,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),

          // Layer 2: Intro Animation (Starts at 100% opacity, plays from frame 1, then cross-fades out)
          if (hasIntro)
            AnimatedOpacity(
              opacity: _introFadeOut ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
              onEnd: () {
                if (_introFadeOut && mounted) {
                  _introProvider?.evict();
                  setState(() {
                    _introDone = true;
                  });
                }
              },
              child: Image(
                image: _introProvider!,
                width: double.infinity,
                height: effectiveHeight,
                fit: BoxFit.fitWidth,
                alignment: Alignment.topCenter,
                filterQuality: FilterQuality.low,
                gaplessPlayback: false,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (frame != null && !_introTimerStarted) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        _startIntroCountdown();
                      }
                    });
                  }
                  return child;
                },
                errorBuilder: (_, __, ___) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _introDone = true;
                      });
                    }
                  });
                  return const SizedBox.shrink();
                },
              ),
            ),
        ],
      ),
    );

    return IgnorePointer(
      child: RepaintBoundary(
        child: effectContent,
      ),
    );
  }
}
