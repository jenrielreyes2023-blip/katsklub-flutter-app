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
      introDuration: Duration(milliseconds: 5040),
    ),
    'clove-s-ruse': ProfileEffectConfig(
      id: 'clove-s-ruse',
      name: 'Clove\'s Ruse',
      introUrl: 'https://media.katsklub.top/effects/clove-s-ruse/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/clove-s-ruse/loop.webp',
      introDuration: Duration(milliseconds: 5040),
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
      introDuration: Duration(milliseconds: 2988),
    ),
    'feelin_90s': ProfileEffectConfig(
      id: 'feelin_90s',
      name: 'Feelin\' 90s',
      introUrl: 'https://media.katsklub.top/effects/feelin-90s/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/feelin-90s/loop.webp',
      introDuration: Duration(milliseconds: 1411),
    ),
    'feelin-90s': ProfileEffectConfig(
      id: 'feelin-90s',
      name: 'Feelin\' 90s',
      introUrl: 'https://media.katsklub.top/effects/feelin-90s/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/feelin-90s/loop.webp',
      introDuration: Duration(milliseconds: 1411),
    ),
    'feelin_mischievous': ProfileEffectConfig(
      id: 'feelin_mischievous',
      name: 'Feelin\' Mischievous',
      introUrl: 'https://media.katsklub.top/effects/feelin-mischievous/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/feelin-mischievous/loop.webp',
      introDuration: Duration(milliseconds: 5064),
    ),
    'feelin-mischievous': ProfileEffectConfig(
      id: 'feelin-mischievous',
      name: 'Feelin\' Mischievous',
      introUrl: 'https://media.katsklub.top/effects/feelin-mischievous/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/feelin-mischievous/loop.webp',
      introDuration: Duration(milliseconds: 5064),
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
      introDuration: Duration(milliseconds: 2880),
    ),
    'fellowship-of-the-spring': ProfileEffectConfig(
      id: 'fellowship-of-the-spring',
      name: 'Fellowship of the Spring',
      introUrl: 'https://media.katsklub.top/effects/fellowship-of-the-spring/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/fellowship-of-the-spring/loop.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'forgotten_treasure': ProfileEffectConfig(
      id: 'forgotten_treasure',
      name: 'Forgotten Treasure',
      introUrl: 'https://media.katsklub.top/effects/forgotten-treasure/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/forgotten-treasure/loop.webp',
      introDuration: Duration(milliseconds: 3520),
    ),
    'forgotten-treasure': ProfileEffectConfig(
      id: 'forgotten-treasure',
      name: 'Forgotten Treasure',
      introUrl: 'https://media.katsklub.top/effects/forgotten-treasure/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/forgotten-treasure/loop.webp',
      introDuration: Duration(milliseconds: 3520),
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
      introDuration: Duration(milliseconds: 4233),
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
      introDuration: Duration(milliseconds: 3735),
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
      introDuration: Duration(milliseconds: 2988),
    ),
    'ki-detonate': ProfileEffectConfig(
      id: 'ki-detonate',
      name: 'Ki Detonate',
      introUrl: 'https://media.katsklub.top/effects/ki-detonate/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/ki-detonate/loop.webp',
      introDuration: Duration(milliseconds: 2988),
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
      introDuration: Duration(milliseconds: 2320),
    ),
    'midnight-celebration': ProfileEffectConfig(
      id: 'midnight-celebration',
      name: 'Midnight Celebration',
      introUrl: 'https://media.katsklub.top/effects/midnight-celebration/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/midnight-celebration/loop.webp',
      introDuration: Duration(milliseconds: 2320),
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
      introDuration: Duration(milliseconds: 3901),
    ),
    'monster-pop': ProfileEffectConfig(
      id: 'monster-pop',
      name: 'Monster Pop',
      introUrl: 'https://media.katsklub.top/effects/monster-pop/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/monster-pop/loop.webp',
      introDuration: Duration(milliseconds: 3901),
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
      introDuration: Duration(milliseconds: 4158),
    ),
    'nice-profile': ProfileEffectConfig(
      id: 'nice-profile',
      name: 'Nice Profile',
      introUrl: 'https://media.katsklub.top/effects/nice-profile/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/nice-profile/loop.webp',
      introDuration: Duration(milliseconds: 4158),
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
      introDuration: Duration(milliseconds: 2960),
    ),
    'rock-slide': ProfileEffectConfig(
      id: 'rock-slide',
      name: 'Rock Slide',
      introUrl: 'https://media.katsklub.top/effects/rock-slide/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/rock-slide/loop.webp',
      introDuration: Duration(milliseconds: 2960),
    ),
    'saya': ProfileEffectConfig(
      id: 'saya',
      name: 'Saya',
      introUrl: 'https://media.katsklub.top/effects/saya/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/saya/loop.webp',
      introDuration: Duration(milliseconds: 3984),
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
      introDuration: Duration(milliseconds: 4150),
    ),
    'snowy-shenanigans': ProfileEffectConfig(
      id: 'snowy-shenanigans',
      name: 'Snowy Shenanigans',
      introUrl: 'https://media.katsklub.top/effects/snowy-shenanigans/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/snowy-shenanigans/loop.webp',
      introDuration: Duration(milliseconds: 4150),
    ),
    'space_evader': ProfileEffectConfig(
      id: 'space_evader',
      name: 'Space Evader',
      introUrl: 'https://media.katsklub.top/effects/space-evader/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/space-evader/loop.webp',
      introDuration: Duration(milliseconds: 4316),
    ),
    'space-evader': ProfileEffectConfig(
      id: 'space-evader',
      name: 'Space Evader',
      introUrl: 'https://media.katsklub.top/effects/space-evader/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/space-evader/loop.webp',
      introDuration: Duration(milliseconds: 4316),
    ),
    'spirit_flame': ProfileEffectConfig(
      id: 'spirit_flame',
      name: 'Spirit Flame',
      introUrl: 'https://media.katsklub.top/effects/spirit-flame/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/spirit-flame/loop.webp',
      introDuration: Duration(milliseconds: 2656),
    ),
    'spirit-flame': ProfileEffectConfig(
      id: 'spirit-flame',
      name: 'Spirit Flame',
      introUrl: 'https://media.katsklub.top/effects/spirit-flame/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/spirit-flame/loop.webp',
      introDuration: Duration(milliseconds: 2656),
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
      introDuration: Duration(milliseconds: 2880),
    ),
    'study-spot': ProfileEffectConfig(
      id: 'study-spot',
      name: 'Study Spot',
      introUrl: 'https://media.katsklub.top/effects/study-spot/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/study-spot/loop.webp',
      introDuration: Duration(milliseconds: 2880),
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
      introDuration: Duration(milliseconds: 2988),
    ),
    'sushi-mania': ProfileEffectConfig(
      id: 'sushi-mania',
      name: 'Sushi Mania',
      introUrl: 'https://media.katsklub.top/effects/sushi-mania/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/sushi-mania/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'the_immortal_clove': ProfileEffectConfig(
      id: 'the_immortal_clove',
      name: 'The Immortal Clove',
      introUrl: 'https://media.katsklub.top/effects/the-immortal-clove/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/the-immortal-clove/loop.webp',
      introDuration: Duration(milliseconds: 5064),
    ),
    'the-immortal-clove': ProfileEffectConfig(
      id: 'the-immortal-clove',
      name: 'The Immortal Clove',
      introUrl: 'https://media.katsklub.top/effects/the-immortal-clove/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/the-immortal-clove/loop.webp',
      introDuration: Duration(milliseconds: 5064),
    ),
    'tocotoco': ProfileEffectConfig(
      id: 'tocotoco',
      name: 'TocoToco',
      introUrl: 'https://media.katsklub.top/effects/tocotoco/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/tocotoco/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'turbo_drive': ProfileEffectConfig(
      id: 'turbo_drive',
      name: 'Turbo Drive',
      introUrl: 'https://media.katsklub.top/effects/turbo-drive/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/turbo-drive/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'turbo-drive': ProfileEffectConfig(
      id: 'turbo-drive',
      name: 'Turbo Drive',
      introUrl: 'https://media.katsklub.top/effects/turbo-drive/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/turbo-drive/loop.webp',
      introDuration: Duration(milliseconds: 2988),
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
      introDuration: Duration(milliseconds: 3984),
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
      introDuration: Duration(milliseconds: 2988),
    ),
    'wake-up': ProfileEffectConfig(
      id: 'wake-up',
      name: 'Wake Up',
      introUrl: 'https://media.katsklub.top/effects/wake-up/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/wake-up/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'watercolors': ProfileEffectConfig(
      id: 'watercolors',
      name: 'Watercolors Splash',
      introUrl: 'https://media.katsklub.top/effects/watercolors/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/watercolors/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'akuma_s_wrath': ProfileEffectConfig(
      id: 'akuma_s_wrath',
      name: 'Akuma\'s Wrath',
      introUrl: 'https://media.katsklub.top/effects/akuma-s-wrath/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/akuma-s-wrath/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'akuma-s-wrath': ProfileEffectConfig(
      id: 'akuma-s-wrath',
      name: 'Akuma\'s Wrath',
      introUrl: 'https://media.katsklub.top/effects/akuma-s-wrath/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/akuma-s-wrath/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'arcane_epiphany': ProfileEffectConfig(
      id: 'arcane_epiphany',
      name: 'Arcane Epiphany',
      introUrl: 'https://media.katsklub.top/effects/arcane-epiphany/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/arcane-epiphany/loop.webp',
      introDuration: Duration(milliseconds: 4150),
    ),
    'arcane-epiphany': ProfileEffectConfig(
      id: 'arcane-epiphany',
      name: 'Arcane Epiphany',
      introUrl: 'https://media.katsklub.top/effects/arcane-epiphany/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/arcane-epiphany/loop.webp',
      introDuration: Duration(milliseconds: 4150),
    ),
    'aurora_dreams': ProfileEffectConfig(
      id: 'aurora_dreams',
      name: 'Aurora Dreams',
      introUrl: 'https://media.katsklub.top/effects/aurora-dreams/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/aurora-dreams/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'aurora-dreams': ProfileEffectConfig(
      id: 'aurora-dreams',
      name: 'Aurora Dreams',
      introUrl: 'https://media.katsklub.top/effects/aurora-dreams/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/aurora-dreams/loop.webp',
      introDuration: Duration(milliseconds: 4980),
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
      introDuration: Duration(milliseconds: 3071),
    ),
    'blazing_ghoulish_graffiti': ProfileEffectConfig(
      id: 'blazing_ghoulish_graffiti',
      name: 'Blazing Graffiti',
      introUrl: 'https://media.katsklub.top/effects/blazing-ghoulish-graffiti/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/blazing-ghoulish-graffiti/loop.webp',
      introDuration: Duration(milliseconds: 2573),
    ),
    'blazing-ghoulish-graffiti': ProfileEffectConfig(
      id: 'blazing-ghoulish-graffiti',
      name: 'Blazing Graffiti',
      introUrl: 'https://media.katsklub.top/effects/blazing-ghoulish-graffiti/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/blazing-ghoulish-graffiti/loop.webp',
      introDuration: Duration(milliseconds: 2573),
    ),
    'bubble_tea_bliss': ProfileEffectConfig(
      id: 'bubble_tea_bliss',
      name: 'Bubble Tea Bliss',
      introUrl: 'https://media.katsklub.top/effects/bubble-tea-bliss/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/bubble-tea-bliss/loop.webp',
      introDuration: Duration(milliseconds: 4535),
    ),
    'bubble-tea-bliss': ProfileEffectConfig(
      id: 'bubble-tea-bliss',
      name: 'Bubble Tea Bliss',
      introUrl: 'https://media.katsklub.top/effects/bubble-tea-bliss/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/bubble-tea-bliss/loop.webp',
      introDuration: Duration(milliseconds: 4535),
    ),
    'bubblegum_zombie_slime': ProfileEffectConfig(
      id: 'bubblegum_zombie_slime',
      name: 'Bubblegum Slime',
      introUrl: 'https://media.katsklub.top/effects/bubblegum-zombie-slime/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/bubblegum-zombie-slime/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'bubblegum-zombie-slime': ProfileEffectConfig(
      id: 'bubblegum-zombie-slime',
      name: 'Bubblegum Slime',
      introUrl: 'https://media.katsklub.top/effects/bubblegum-zombie-slime/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/bubblegum-zombie-slime/loop.webp',
      introDuration: Duration(milliseconds: 2988),
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
      introDuration: Duration(milliseconds: 3486),
    ),
    'classic-street-fighter': ProfileEffectConfig(
      id: 'classic-street-fighter',
      name: 'Classic Fighter',
      introUrl: 'https://media.katsklub.top/effects/classic-street-fighter/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/classic-street-fighter/loop.webp',
      introDuration: Duration(milliseconds: 3486),
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
      introDuration: Duration(milliseconds: 1743),
    ),
    'deck-the-halls-aurora': ProfileEffectConfig(
      id: 'deck-the-halls-aurora',
      name: 'Deck the Halls Aurora',
      introUrl: 'https://media.katsklub.top/effects/deck-the-halls-aurora/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/deck-the-halls-aurora/loop.webp',
      introDuration: Duration(milliseconds: 1743),
    ),
    'deck_the_halls_dusk': ProfileEffectConfig(
      id: 'deck_the_halls_dusk',
      name: 'Deck the Halls Dusk',
      introUrl: 'https://media.katsklub.top/effects/deck-the-halls-dusk/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/deck-the-halls-dusk/loop.webp',
      introDuration: Duration(milliseconds: 1743),
    ),
    'deck-the-halls-dusk': ProfileEffectConfig(
      id: 'deck-the-halls-dusk',
      name: 'Deck the Halls Dusk',
      introUrl: 'https://media.katsklub.top/effects/deck-the-halls-dusk/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/deck-the-halls-dusk/loop.webp',
      introDuration: Duration(milliseconds: 1743),
    ),
    'deck_the_halls_ember': ProfileEffectConfig(
      id: 'deck_the_halls_ember',
      name: 'Deck the Halls Ember',
      introUrl: 'https://media.katsklub.top/effects/deck-the-halls-ember/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/deck-the-halls-ember/loop.webp',
      introDuration: Duration(milliseconds: 1743),
    ),
    'deck-the-halls-ember': ProfileEffectConfig(
      id: 'deck-the-halls-ember',
      name: 'Deck the Halls Ember',
      introUrl: 'https://media.katsklub.top/effects/deck-the-halls-ember/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/deck-the-halls-ember/loop.webp',
      introDuration: Duration(milliseconds: 1743),
    ),
    'deck_the_halls_mix': ProfileEffectConfig(
      id: 'deck_the_halls_mix',
      name: 'Deck the Halls Mix',
      introUrl: 'https://media.katsklub.top/effects/deck-the-halls-mix/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/deck-the-halls-mix/loop.webp',
      introDuration: Duration(milliseconds: 1743),
    ),
    'deck-the-halls-mix': ProfileEffectConfig(
      id: 'deck-the-halls-mix',
      name: 'Deck the Halls Mix',
      introUrl: 'https://media.katsklub.top/effects/deck-the-halls-mix/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/deck-the-halls-mix/loop.webp',
      introDuration: Duration(milliseconds: 1743),
    ),
    'ekko_s_aeroglider_stunts': ProfileEffectConfig(
      id: 'ekko_s_aeroglider_stunts',
      name: 'Ekko\'s Aeroglider',
      introUrl: 'https://media.katsklub.top/effects/ekko-s-aeroglider-stunts/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/ekko-s-aeroglider-stunts/loop.webp',
      introDuration: Duration(milliseconds: 3071),
    ),
    'ekko-s-aeroglider-stunts': ProfileEffectConfig(
      id: 'ekko-s-aeroglider-stunts',
      name: 'Ekko\'s Aeroglider',
      introUrl: 'https://media.katsklub.top/effects/ekko-s-aeroglider-stunts/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/ekko-s-aeroglider-stunts/loop.webp',
      introDuration: Duration(milliseconds: 3071),
    ),
    'enchanted_forest': ProfileEffectConfig(
      id: 'enchanted_forest',
      name: 'Enchanted Forest',
      introUrl: 'https://media.katsklub.top/effects/enchanted-forest/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/enchanted-forest/loop.webp',
      introDuration: Duration(milliseconds: 3071),
    ),
    'enchanted-forest': ProfileEffectConfig(
      id: 'enchanted-forest',
      name: 'Enchanted Forest',
      introUrl: 'https://media.katsklub.top/effects/enchanted-forest/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/enchanted-forest/loop.webp',
      introDuration: Duration(milliseconds: 3071),
    ),
    'flutter_and_frolic': ProfileEffectConfig(
      id: 'flutter_and_frolic',
      name: 'Flutter & Frolic',
      introUrl: 'https://media.katsklub.top/effects/flutter-and-frolic/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/flutter-and-frolic/loop.webp',
      introDuration: Duration(milliseconds: 3405),
    ),
    'flutter-and-frolic': ProfileEffectConfig(
      id: 'flutter-and-frolic',
      name: 'Flutter & Frolic',
      introUrl: 'https://media.katsklub.top/effects/flutter-and-frolic/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/flutter-and-frolic/loop.webp',
      introDuration: Duration(milliseconds: 3405),
    ),
    'fog_of_war': ProfileEffectConfig(
      id: 'fog_of_war',
      name: 'Fog of War',
      introUrl: 'https://media.katsklub.top/effects/fog-of-war/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/fog-of-war/loop.webp',
      introDuration: Duration(milliseconds: 4316),
    ),
    'fog-of-war': ProfileEffectConfig(
      id: 'fog-of-war',
      name: 'Fog of War',
      introUrl: 'https://media.katsklub.top/effects/fog-of-war/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/fog-of-war/loop.webp',
      introDuration: Duration(milliseconds: 4316),
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
      introDuration: Duration(milliseconds: 2988),
    ),
    'infernal-dark-omens': ProfileEffectConfig(
      id: 'infernal-dark-omens',
      name: 'Infernal Omens',
      introUrl: 'https://media.katsklub.top/effects/infernal-dark-omens/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/infernal-dark-omens/loop.webp',
      introDuration: Duration(milliseconds: 2988),
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
      introDuration: Duration(milliseconds: 4317),
    ),
    'jinx-and-pow-pow': ProfileEffectConfig(
      id: 'jinx-and-pow-pow',
      name: 'Jinx & Pow-Pow',
      introUrl: 'https://media.katsklub.top/effects/jinx-and-pow-pow/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/jinx-and-pow-pow/loop.webp',
      introDuration: Duration(milliseconds: 4317),
    ),
    'kawaii_mode': ProfileEffectConfig(
      id: 'kawaii_mode',
      name: 'Kawaii Mode',
      introUrl: 'https://media.katsklub.top/effects/kawaii-mode/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/kawaii-mode/loop.webp',
      introDuration: Duration(milliseconds: 4410),
    ),
    'kawaii-mode': ProfileEffectConfig(
      id: 'kawaii-mode',
      name: 'Kawaii Mode',
      introUrl: 'https://media.katsklub.top/effects/kawaii-mode/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/kawaii-mode/loop.webp',
      introDuration: Duration(milliseconds: 4410),
    ),
    'koi_garden': ProfileEffectConfig(
      id: 'koi_garden',
      name: 'Koi Garden',
      introUrl: 'https://media.katsklub.top/effects/koi-garden/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/koi-garden/loop.webp',
      introDuration: Duration(milliseconds: 3652),
    ),
    'koi-garden': ProfileEffectConfig(
      id: 'koi-garden',
      name: 'Koi Garden',
      introUrl: 'https://media.katsklub.top/effects/koi-garden/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/koi-garden/loop.webp',
      introDuration: Duration(milliseconds: 3652),
    ),
    'lofi_cat_zoomies_festive': ProfileEffectConfig(
      id: 'lofi_cat_zoomies_festive',
      name: 'Festive Cat Zoomies',
      introUrl: 'https://media.katsklub.top/effects/lofi-cat-zoomies-festive/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/lofi-cat-zoomies-festive/loop.webp',
      introDuration: Duration(milliseconds: 5148),
    ),
    'lofi-cat-zoomies-festive': ProfileEffectConfig(
      id: 'lofi-cat-zoomies-festive',
      name: 'Festive Cat Zoomies',
      introUrl: 'https://media.katsklub.top/effects/lofi-cat-zoomies-festive/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/lofi-cat-zoomies-festive/loop.webp',
      introDuration: Duration(milliseconds: 5148),
    ),
    'lofi_girl_snow_angel': ProfileEffectConfig(
      id: 'lofi_girl_snow_angel',
      name: 'Snow Angel Lofi',
      introUrl: 'https://media.katsklub.top/effects/lofi-girl-snow-angel/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/lofi-girl-snow-angel/loop.webp',
      introDuration: Duration(milliseconds: 4985),
    ),
    'lofi-girl-snow-angel': ProfileEffectConfig(
      id: 'lofi-girl-snow-angel',
      name: 'Snow Angel Lofi',
      introUrl: 'https://media.katsklub.top/effects/lofi-girl-snow-angel/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/lofi-girl-snow-angel/loop.webp',
      introDuration: Duration(milliseconds: 4985),
    ),
    'lofi_girl_study_break': ProfileEffectConfig(
      id: 'lofi_girl_study_break',
      name: 'Study Break Lofi',
      introUrl: 'https://media.katsklub.top/effects/lofi-girl-study-break/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/lofi-girl-study-break/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'lofi-girl-study-break': ProfileEffectConfig(
      id: 'lofi-girl-study-break',
      name: 'Study Break Lofi',
      introUrl: 'https://media.katsklub.top/effects/lofi-girl-study-break/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/lofi-girl-study-break/loop.webp',
      introDuration: Duration(milliseconds: 4980),
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
      introDuration: Duration(milliseconds: 4318),
    ),
    'mermaid-whisperer': ProfileEffectConfig(
      id: 'mermaid-whisperer',
      name: 'Mermaid Whisperer',
      introUrl: 'https://media.katsklub.top/effects/mermaid-whisperer/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/mermaid-whisperer/loop.webp',
      introDuration: Duration(milliseconds: 4318),
    ),
    'midnight_dark_omens': ProfileEffectConfig(
      id: 'midnight_dark_omens',
      name: 'Midnight Omens',
      introUrl: 'https://media.katsklub.top/effects/midnight-dark-omens/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/midnight-dark-omens/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'midnight-dark-omens': ProfileEffectConfig(
      id: 'midnight-dark-omens',
      name: 'Midnight Omens',
      introUrl: 'https://media.katsklub.top/effects/midnight-dark-omens/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/midnight-dark-omens/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'midnight_zombie_slime': ProfileEffectConfig(
      id: 'midnight_zombie_slime',
      name: 'Midnight Slime',
      introUrl: 'https://media.katsklub.top/effects/midnight-zombie-slime/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/midnight-zombie-slime/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'midnight-zombie-slime': ProfileEffectConfig(
      id: 'midnight-zombie-slime',
      name: 'Midnight Slime',
      introUrl: 'https://media.katsklub.top/effects/midnight-zombie-slime/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/midnight-zombie-slime/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'mimic': ProfileEffectConfig(
      id: 'mimic',
      name: 'Mimic Chest',
      introUrl: 'https://media.katsklub.top/effects/mimic/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/mimic/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'mooncap_forest_blue': ProfileEffectConfig(
      id: 'mooncap_forest_blue',
      name: 'Mooncap Forest Blue',
      introUrl: 'https://media.katsklub.top/effects/mooncap-forest-blue/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/mooncap-forest-blue/loop.webp',
      introDuration: Duration(milliseconds: 3071),
    ),
    'mooncap-forest-blue': ProfileEffectConfig(
      id: 'mooncap-forest-blue',
      name: 'Mooncap Forest Blue',
      introUrl: 'https://media.katsklub.top/effects/mooncap-forest-blue/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/mooncap-forest-blue/loop.webp',
      introDuration: Duration(milliseconds: 3071),
    ),
    'mooncap_forest_pink': ProfileEffectConfig(
      id: 'mooncap_forest_pink',
      name: 'Mooncap Forest Pink',
      introUrl: 'https://media.katsklub.top/effects/mooncap-forest-pink/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/mooncap-forest-pink/loop.webp',
      introDuration: Duration(milliseconds: 3071),
    ),
    'mooncap-forest-pink': ProfileEffectConfig(
      id: 'mooncap-forest-pink',
      name: 'Mooncap Forest Pink',
      introUrl: 'https://media.katsklub.top/effects/mooncap-forest-pink/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/mooncap-forest-pink/loop.webp',
      introDuration: Duration(milliseconds: 3071),
    ),
    'neon_ghoulish_graffiti': ProfileEffectConfig(
      id: 'neon_ghoulish_graffiti',
      name: 'Neon Graffiti',
      introUrl: 'https://media.katsklub.top/effects/neon-ghoulish-graffiti/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/neon-ghoulish-graffiti/loop.webp',
      introDuration: Duration(milliseconds: 2573),
    ),
    'neon-ghoulish-graffiti': ProfileEffectConfig(
      id: 'neon-ghoulish-graffiti',
      name: 'Neon Graffiti',
      introUrl: 'https://media.katsklub.top/effects/neon-ghoulish-graffiti/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/neon-ghoulish-graffiti/loop.webp',
      introDuration: Duration(milliseconds: 2573),
    ),
    'ocean_flowers': ProfileEffectConfig(
      id: 'ocean_flowers',
      name: 'Ocean Flowers',
      introUrl: 'https://media.katsklub.top/effects/ocean-flowers/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/ocean-flowers/loop.webp',
      introDuration: Duration(milliseconds: 3818),
    ),
    'ocean-flowers': ProfileEffectConfig(
      id: 'ocean-flowers',
      name: 'Ocean Flowers',
      introUrl: 'https://media.katsklub.top/effects/ocean-flowers/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/ocean-flowers/loop.webp',
      introDuration: Duration(milliseconds: 3818),
    ),
    'of_ink_and_steel': ProfileEffectConfig(
      id: 'of_ink_and_steel',
      name: 'Of Ink & Steel',
      introUrl: 'https://media.katsklub.top/effects/of-ink-and-steel/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/of-ink-and-steel/loop.webp',
      introDuration: Duration(milliseconds: 3920),
    ),
    'of-ink-and-steel': ProfileEffectConfig(
      id: 'of-ink-and-steel',
      name: 'Of Ink & Steel',
      introUrl: 'https://media.katsklub.top/effects/of-ink-and-steel/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/of-ink-and-steel/loop.webp',
      introDuration: Duration(milliseconds: 3920),
    ),
    'oni_s_curse': ProfileEffectConfig(
      id: 'oni_s_curse',
      name: 'Oni\'s Curse',
      introUrl: 'https://media.katsklub.top/effects/oni-s-curse/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/oni-s-curse/loop.webp',
      introDuration: Duration(milliseconds: 2905),
    ),
    'oni-s-curse': ProfileEffectConfig(
      id: 'oni-s-curse',
      name: 'Oni\'s Curse',
      introUrl: 'https://media.katsklub.top/effects/oni-s-curse/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/oni-s-curse/loop.webp',
      introDuration: Duration(milliseconds: 2905),
    ),
    'paint_the_town_blue': ProfileEffectConfig(
      id: 'paint_the_town_blue',
      name: 'Paint The Town Blue',
      introUrl: 'https://media.katsklub.top/effects/paint-the-town-blue/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/paint-the-town-blue/loop.webp',
      introDuration: Duration(milliseconds: 3901),
    ),
    'paint-the-town-blue': ProfileEffectConfig(
      id: 'paint-the-town-blue',
      name: 'Paint The Town Blue',
      introUrl: 'https://media.katsklub.top/effects/paint-the-town-blue/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/paint-the-town-blue/loop.webp',
      introDuration: Duration(milliseconds: 3901),
    ),
    'penguins_on_ice': ProfileEffectConfig(
      id: 'penguins_on_ice',
      name: 'Penguins on Ice',
      introUrl: 'https://media.katsklub.top/effects/penguins-on-ice/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/penguins-on-ice/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'penguins-on-ice': ProfileEffectConfig(
      id: 'penguins-on-ice',
      name: 'Penguins on Ice',
      introUrl: 'https://media.katsklub.top/effects/penguins-on-ice/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/penguins-on-ice/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'plankton_splat': ProfileEffectConfig(
      id: 'plankton_splat',
      name: 'Plankton Splat',
      introUrl: 'https://media.katsklub.top/effects/plankton-splat/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/plankton-splat/loop.webp',
      introDuration: Duration(milliseconds: 4326),
    ),
    'plankton-splat': ProfileEffectConfig(
      id: 'plankton-splat',
      name: 'Plankton Splat',
      introUrl: 'https://media.katsklub.top/effects/plankton-splat/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/plankton-splat/loop.webp',
      introDuration: Duration(milliseconds: 4326),
    ),
    'plushie_party': ProfileEffectConfig(
      id: 'plushie_party',
      name: 'Plushie Party',
      introUrl: 'https://media.katsklub.top/effects/plushie-party/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/plushie-party/loop.webp',
      introDuration: Duration(milliseconds: 3441),
    ),
    'plushie-party': ProfileEffectConfig(
      id: 'plushie-party',
      name: 'Plushie Party',
      introUrl: 'https://media.katsklub.top/effects/plushie-party/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/plushie-party/loop.webp',
      introDuration: Duration(milliseconds: 3441),
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
      introDuration: Duration(milliseconds: 3486),
    ),
    'red-dragon': ProfileEffectConfig(
      id: 'red-dragon',
      name: 'Red Dragon',
      introUrl: 'https://media.katsklub.top/effects/red-dragon/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/red-dragon/loop.webp',
      introDuration: Duration(milliseconds: 3486),
    ),
    'sakura_katana': ProfileEffectConfig(
      id: 'sakura_katana',
      name: 'Sakura Katana',
      introUrl: 'https://media.katsklub.top/effects/sakura-katana/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/sakura-katana/loop.webp',
      introDuration: Duration(milliseconds: 2407),
    ),
    'sakura-katana': ProfileEffectConfig(
      id: 'sakura-katana',
      name: 'Sakura Katana',
      introUrl: 'https://media.katsklub.top/effects/sakura-katana/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/sakura-katana/loop.webp',
      introDuration: Duration(milliseconds: 2407),
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
      introDuration: Duration(milliseconds: 4150),
    ),
    'snowy-shenanigans-giddy': ProfileEffectConfig(
      id: 'snowy-shenanigans-giddy',
      name: 'Snowy Giddy',
      introUrl: 'https://media.katsklub.top/effects/snowy-shenanigans-giddy/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/snowy-shenanigans-giddy/loop.webp',
      introDuration: Duration(milliseconds: 4150),
    ),
    'snowy_shenanigans_jolly': ProfileEffectConfig(
      id: 'snowy_shenanigans_jolly',
      name: 'Snowy Jolly',
      introUrl: 'https://media.katsklub.top/effects/snowy-shenanigans-jolly/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/snowy-shenanigans-jolly/loop.webp',
      introDuration: Duration(milliseconds: 4150),
    ),
    'snowy-shenanigans-jolly': ProfileEffectConfig(
      id: 'snowy-shenanigans-jolly',
      name: 'Snowy Jolly',
      introUrl: 'https://media.katsklub.top/effects/snowy-shenanigans-jolly/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/snowy-shenanigans-jolly/loop.webp',
      introDuration: Duration(milliseconds: 4150),
    ),
    'snowy_shenanigans_smooch': ProfileEffectConfig(
      id: 'snowy_shenanigans_smooch',
      name: 'Snowy Smooch',
      introUrl: 'https://media.katsklub.top/effects/snowy-shenanigans-smooch/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/snowy-shenanigans-smooch/loop.webp',
      introDuration: Duration(milliseconds: 4150),
    ),
    'snowy-shenanigans-smooch': ProfileEffectConfig(
      id: 'snowy-shenanigans-smooch',
      name: 'Snowy Smooch',
      introUrl: 'https://media.katsklub.top/effects/snowy-shenanigans-smooch/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/snowy-shenanigans-smooch/loop.webp',
      introDuration: Duration(milliseconds: 4150),
    ),
    'snowy_shenanigans_suave': ProfileEffectConfig(
      id: 'snowy_shenanigans_suave',
      name: 'Snowy Suave',
      introUrl: 'https://media.katsklub.top/effects/snowy-shenanigans-suave/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/snowy-shenanigans-suave/loop.webp',
      introDuration: Duration(milliseconds: 4150),
    ),
    'snowy-shenanigans-suave': ProfileEffectConfig(
      id: 'snowy-shenanigans-suave',
      name: 'Snowy Suave',
      introUrl: 'https://media.katsklub.top/effects/snowy-shenanigans-suave/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/snowy-shenanigans-suave/loop.webp',
      introDuration: Duration(milliseconds: 4150),
    ),
    'spirit_of_the_kitsune': ProfileEffectConfig(
      id: 'spirit_of_the_kitsune',
      name: 'Spirit of the Kitsune',
      introUrl: 'https://media.katsklub.top/effects/spirit-of-the-kitsune/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/spirit-of-the-kitsune/loop.webp',
      introDuration: Duration(milliseconds: 6640),
    ),
    'spirit-of-the-kitsune': ProfileEffectConfig(
      id: 'spirit-of-the-kitsune',
      name: 'Spirit of the Kitsune',
      introUrl: 'https://media.katsklub.top/effects/spirit-of-the-kitsune/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/spirit-of-the-kitsune/loop.webp',
      introDuration: Duration(milliseconds: 6640),
    ),
    'street_fighter_6': ProfileEffectConfig(
      id: 'street_fighter_6',
      name: 'Street Fighter 6',
      introUrl: 'https://media.katsklub.top/effects/street-fighter-6/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/street-fighter-6/loop.webp',
      introDuration: Duration(milliseconds: 3984),
    ),
    'street-fighter-6': ProfileEffectConfig(
      id: 'street-fighter-6',
      name: 'Street Fighter 6',
      introUrl: 'https://media.katsklub.top/effects/street-fighter-6/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/street-fighter-6/loop.webp',
      introDuration: Duration(milliseconds: 3984),
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
      introDuration: Duration(milliseconds: 4981),
    ),
    'twist-of-luck': ProfileEffectConfig(
      id: 'twist-of-luck',
      name: 'Twist of Luck',
      introUrl: 'https://media.katsklub.top/effects/twist-of-luck/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/twist-of-luck/loop.webp',
      introDuration: Duration(milliseconds: 4981),
    ),
    'vct_supernova': ProfileEffectConfig(
      id: 'vct_supernova',
      name: 'VCT Champions Supernova',
      introUrl: 'https://media.katsklub.top/effects/vct-supernova/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/vct-supernova/loop.webp',
      introDuration: Duration(milliseconds: 4650),
    ),
    'vct-supernova': ProfileEffectConfig(
      id: 'vct-supernova',
      name: 'VCT Champions Supernova',
      introUrl: 'https://media.katsklub.top/effects/vct-supernova/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/vct-supernova/loop.webp',
      introDuration: Duration(milliseconds: 4650),
    ),
    'wonder_construction': ProfileEffectConfig(
      id: 'wonder_construction',
      name: 'Wonder Construction',
      introUrl: 'https://media.katsklub.top/effects/wonder-construction/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/wonder-construction/loop.webp',
      introDuration: Duration(milliseconds: 4897),
    ),
    'wonder-construction': ProfileEffectConfig(
      id: 'wonder-construction',
      name: 'Wonder Construction',
      introUrl: 'https://media.katsklub.top/effects/wonder-construction/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/wonder-construction/loop.webp',
      introDuration: Duration(milliseconds: 4897),
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
      introDuration: Duration(milliseconds: 4100),
    ),
    'yoru-dimensional-rip': ProfileEffectConfig(
      id: 'yoru-dimensional-rip',
      name: 'Yoru\'s Drift',
      introUrl: 'https://media.katsklub.top/effects/yoru-dimensional-rip/intro.webp',
      loopUrl: 'https://media.katsklub.top/effects/yoru-dimensional-rip/loop.webp',
      introDuration: Duration(milliseconds: 4100),
    ),
    'bearly_afloat': ProfileEffectConfig(
      id: 'bearly_afloat',
      name: 'Bearly Afloat',
      introUrl: 'https://cdn.katsklub.top/effects/bearly-afloat/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/bearly-afloat/loop.webp',
      introDuration: Duration(milliseconds: 3789),
    ),
    'bearly-afloat': ProfileEffectConfig(
      id: 'bearly-afloat',
      name: 'Bearly Afloat',
      introUrl: 'https://cdn.katsklub.top/effects/bearly-afloat/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/bearly-afloat/loop.webp',
      introDuration: Duration(milliseconds: 3789),
    ),
    'capyccino': ProfileEffectConfig(
      id: 'capyccino',
      name: 'Capyccino',
      introUrl: 'https://cdn.katsklub.top/effects/capyccino/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/capyccino/loop.webp',
      introDuration: Duration(milliseconds: 5795),
    ),
    'close_combat': ProfileEffectConfig(
      id: 'close_combat',
      name: 'Close Combat',
      introUrl: 'https://cdn.katsklub.top/effects/close-combat/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/close-combat/loop.webp',
      introDuration: Duration(milliseconds: 4319),
    ),
    'close-combat': ProfileEffectConfig(
      id: 'close-combat',
      name: 'Close Combat',
      introUrl: 'https://cdn.katsklub.top/effects/close-combat/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/close-combat/loop.webp',
      introDuration: Duration(milliseconds: 4319),
    ),
    'cluster': ProfileEffectConfig(
      id: 'cluster',
      name: 'Cluster',
      introUrl: 'https://cdn.katsklub.top/effects/cluster/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/cluster/loop.webp',
      introDuration: Duration(milliseconds: 2905),
    ),
    'darth_vader_arrives': ProfileEffectConfig(
      id: 'darth_vader_arrives',
      name: 'Darth Vader Arrives',
      introUrl: 'https://cdn.katsklub.top/effects/darth-vader-arrives/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/darth-vader-arrives/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'darth-vader-arrives': ProfileEffectConfig(
      id: 'darth-vader-arrives',
      name: 'Darth Vader Arrives',
      introUrl: 'https://cdn.katsklub.top/effects/darth-vader-arrives/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/darth-vader-arrives/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'deep_dive': ProfileEffectConfig(
      id: 'deep_dive',
      name: 'Deep Dive',
      introUrl: 'https://cdn.katsklub.top/effects/deep-dive/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/deep-dive/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'deep-dive': ProfileEffectConfig(
      id: 'deep-dive',
      name: 'Deep Dive',
      introUrl: 'https://cdn.katsklub.top/effects/deep-dive/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/deep-dive/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'dreamy_blue': ProfileEffectConfig(
      id: 'dreamy_blue',
      name: 'Dreamy Blue',
      introUrl: 'https://cdn.katsklub.top/effects/dreamy-blue/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/dreamy-blue/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'dreamy-blue': ProfileEffectConfig(
      id: 'dreamy-blue',
      name: 'Dreamy Blue',
      introUrl: 'https://cdn.katsklub.top/effects/dreamy-blue/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/dreamy-blue/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'dreamy_green': ProfileEffectConfig(
      id: 'dreamy_green',
      name: 'Dreamy Green',
      introUrl: 'https://cdn.katsklub.top/effects/dreamy-green/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/dreamy-green/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'dreamy-green': ProfileEffectConfig(
      id: 'dreamy-green',
      name: 'Dreamy Green',
      introUrl: 'https://cdn.katsklub.top/effects/dreamy-green/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/dreamy-green/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'dreamy_pink': ProfileEffectConfig(
      id: 'dreamy_pink',
      name: 'Dreamy Pink',
      introUrl: 'https://cdn.katsklub.top/effects/dreamy-pink/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/dreamy-pink/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'dreamy-pink': ProfileEffectConfig(
      id: 'dreamy-pink',
      name: 'Dreamy Pink',
      introUrl: 'https://cdn.katsklub.top/effects/dreamy-pink/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/dreamy-pink/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'dreamy_yellow': ProfileEffectConfig(
      id: 'dreamy_yellow',
      name: 'Dreamy Yellow',
      introUrl: 'https://cdn.katsklub.top/effects/dreamy-yellow/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/dreamy-yellow/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'dreamy-yellow': ProfileEffectConfig(
      id: 'dreamy-yellow',
      name: 'Dreamy Yellow',
      introUrl: 'https://cdn.katsklub.top/effects/dreamy-yellow/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/dreamy-yellow/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'entering_hyperspace': ProfileEffectConfig(
      id: 'entering_hyperspace',
      name: 'Entering Hyperspace',
      introUrl: 'https://cdn.katsklub.top/effects/entering-hyperspace/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/entering-hyperspace/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'entering-hyperspace': ProfileEffectConfig(
      id: 'entering-hyperspace',
      name: 'Entering Hyperspace',
      introUrl: 'https://cdn.katsklub.top/effects/entering-hyperspace/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/entering-hyperspace/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'f_in_chat_black': ProfileEffectConfig(
      id: 'f_in_chat_black',
      name: 'F in Chat Black',
      introUrl: 'https://cdn.katsklub.top/effects/f-in-chat-black/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/f-in-chat-black/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'f-in-chat-black': ProfileEffectConfig(
      id: 'f-in-chat-black',
      name: 'F in Chat Black',
      introUrl: 'https://cdn.katsklub.top/effects/f-in-chat-black/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/f-in-chat-black/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'f_in_chat_white': ProfileEffectConfig(
      id: 'f_in_chat_white',
      name: 'F in Chat White',
      introUrl: 'https://cdn.katsklub.top/effects/f-in-chat-white/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/f-in-chat-white/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'f-in-chat-white': ProfileEffectConfig(
      id: 'f-in-chat-white',
      name: 'F in Chat White',
      introUrl: 'https://cdn.katsklub.top/effects/f-in-chat-white/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/f-in-chat-white/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'farming_town': ProfileEffectConfig(
      id: 'farming_town',
      name: 'Farming Town',
      introUrl: 'https://cdn.katsklub.top/effects/farming-town/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/farming-town/loop.webp',
      introDuration: Duration(milliseconds: 6250),
    ),
    'farming-town': ProfileEffectConfig(
      id: 'farming-town',
      name: 'Farming Town',
      introUrl: 'https://cdn.katsklub.top/effects/farming-town/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/farming-town/loop.webp',
      introDuration: Duration(milliseconds: 6250),
    ),
    'fishing_village': ProfileEffectConfig(
      id: 'fishing_village',
      name: 'Fishing Village',
      introUrl: 'https://cdn.katsklub.top/effects/fishing-village/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/fishing-village/loop.webp',
      introDuration: Duration(milliseconds: 9000),
    ),
    'fishing-village': ProfileEffectConfig(
      id: 'fishing-village',
      name: 'Fishing Village',
      introUrl: 'https://cdn.katsklub.top/effects/fishing-village/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/fishing-village/loop.webp',
      introDuration: Duration(milliseconds: 9000),
    ),
    'full_cowling': ProfileEffectConfig(
      id: 'full_cowling',
      name: 'Full Cowling',
      introUrl: 'https://cdn.katsklub.top/effects/full-cowling/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/full-cowling/loop.webp',
      introDuration: Duration(milliseconds: 2905),
    ),
    'full-cowling': ProfileEffectConfig(
      id: 'full-cowling',
      name: 'Full Cowling',
      introUrl: 'https://cdn.katsklub.top/effects/full-cowling/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/full-cowling/loop.webp',
      introDuration: Duration(milliseconds: 2905),
    ),
    'giselle': ProfileEffectConfig(
      id: 'giselle',
      name: 'Giselle',
      introUrl: 'https://cdn.katsklub.top/effects/giselle/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/giselle/loop.webp',
      introDuration: Duration(milliseconds: 3238),
    ),
    'heartstring_theory_blue': ProfileEffectConfig(
      id: 'heartstring_theory_blue',
      name: 'Heartstring Theory Blue',
      introUrl: 'https://cdn.katsklub.top/effects/heartstring-theory-blue/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/heartstring-theory-blue/loop.webp',
      introDuration: Duration(milliseconds: 2120),
    ),
    'heartstring-theory-blue': ProfileEffectConfig(
      id: 'heartstring-theory-blue',
      name: 'Heartstring Theory Blue',
      introUrl: 'https://cdn.katsklub.top/effects/heartstring-theory-blue/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/heartstring-theory-blue/loop.webp',
      introDuration: Duration(milliseconds: 2120),
    ),
    'heartstring_theory_red': ProfileEffectConfig(
      id: 'heartstring_theory_red',
      name: 'Heartstring Theory Red',
      introUrl: 'https://cdn.katsklub.top/effects/heartstring-theory-red/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/heartstring-theory-red/loop.webp',
      introDuration: Duration(milliseconds: 2120),
    ),
    'heartstring-theory-red': ProfileEffectConfig(
      id: 'heartstring-theory-red',
      name: 'Heartstring Theory Red',
      introUrl: 'https://cdn.katsklub.top/effects/heartstring-theory-red/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/heartstring-theory-red/loop.webp',
      introDuration: Duration(milliseconds: 2120),
    ),
    'karina': ProfileEffectConfig(
      id: 'karina',
      name: 'Karina',
      introUrl: 'https://cdn.katsklub.top/effects/karina/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/karina/loop.webp',
      introDuration: Duration(milliseconds: 3238),
    ),
    'keyboard_cats': ProfileEffectConfig(
      id: 'keyboard_cats',
      name: 'Keyboard Cats',
      introUrl: 'https://cdn.katsklub.top/effects/keyboard-cats/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/keyboard-cats/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'keyboard-cats': ProfileEffectConfig(
      id: 'keyboard-cats',
      name: 'Keyboard Cats',
      introUrl: 'https://cdn.katsklub.top/effects/keyboard-cats/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/keyboard-cats/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'ki_detonate_blue': ProfileEffectConfig(
      id: 'ki_detonate_blue',
      name: 'Ki Detonate Blue',
      introUrl: 'https://cdn.katsklub.top/effects/ki-detonate-blue/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/ki-detonate-blue/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'ki-detonate-blue': ProfileEffectConfig(
      id: 'ki-detonate-blue',
      name: 'Ki Detonate Blue',
      introUrl: 'https://cdn.katsklub.top/effects/ki-detonate-blue/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/ki-detonate-blue/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'ki_detonate_green': ProfileEffectConfig(
      id: 'ki_detonate_green',
      name: 'Ki Detonate Green',
      introUrl: 'https://cdn.katsklub.top/effects/ki-detonate-green/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/ki-detonate-green/loop.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'ki-detonate-green': ProfileEffectConfig(
      id: 'ki-detonate-green',
      name: 'Ki Detonate Green',
      introUrl: 'https://cdn.katsklub.top/effects/ki-detonate-green/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/ki-detonate-green/loop.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'ki_detonate_red': ProfileEffectConfig(
      id: 'ki_detonate_red',
      name: 'Ki Detonate Red',
      introUrl: 'https://cdn.katsklub.top/effects/ki-detonate-red/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/ki-detonate-red/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'ki-detonate-red': ProfileEffectConfig(
      id: 'ki-detonate-red',
      name: 'Ki Detonate Red',
      introUrl: 'https://cdn.katsklub.top/effects/ki-detonate-red/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/ki-detonate-red/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'ki_detonate_yellow': ProfileEffectConfig(
      id: 'ki_detonate_yellow',
      name: 'Ki Detonate Yellow',
      introUrl: 'https://cdn.katsklub.top/effects/ki-detonate-yellow/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/ki-detonate-yellow/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'ki-detonate-yellow': ProfileEffectConfig(
      id: 'ki-detonate-yellow',
      name: 'Ki Detonate Yellow',
      introUrl: 'https://cdn.katsklub.top/effects/ki-detonate-yellow/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/ki-detonate-yellow/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'lava_lamp': ProfileEffectConfig(
      id: 'lava_lamp',
      name: 'Lava Lamp',
      introUrl: 'https://cdn.katsklub.top/effects/lava-lamp/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/lava-lamp/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'lava-lamp': ProfileEffectConfig(
      id: 'lava-lamp',
      name: 'Lava Lamp',
      introUrl: 'https://cdn.katsklub.top/effects/lava-lamp/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/lava-lamp/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'lava_lamp_blue': ProfileEffectConfig(
      id: 'lava_lamp_blue',
      name: 'Lava Lamp Blue',
      introUrl: 'https://cdn.katsklub.top/effects/lava-lamp-blue/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/lava-lamp-blue/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'lava-lamp-blue': ProfileEffectConfig(
      id: 'lava-lamp-blue',
      name: 'Lava Lamp Blue',
      introUrl: 'https://cdn.katsklub.top/effects/lava-lamp-blue/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/lava-lamp-blue/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'lava_lamp_pink': ProfileEffectConfig(
      id: 'lava_lamp_pink',
      name: 'Lava Lamp Pink',
      introUrl: 'https://cdn.katsklub.top/effects/lava-lamp-pink/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/lava-lamp-pink/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'lava-lamp-pink': ProfileEffectConfig(
      id: 'lava-lamp-pink',
      name: 'Lava Lamp Pink',
      introUrl: 'https://cdn.katsklub.top/effects/lava-lamp-pink/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/lava-lamp-pink/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'lava_lamp_slime': ProfileEffectConfig(
      id: 'lava_lamp_slime',
      name: 'Lava Lamp Slime',
      introUrl: 'https://cdn.katsklub.top/effects/lava-lamp-slime/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/lava-lamp-slime/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'lava-lamp-slime': ProfileEffectConfig(
      id: 'lava-lamp-slime',
      name: 'Lava Lamp Slime',
      introUrl: 'https://cdn.katsklub.top/effects/lava-lamp-slime/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/lava-lamp-slime/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'lazy_loaf': ProfileEffectConfig(
      id: 'lazy_loaf',
      name: 'Lazy Loaf',
      introUrl: 'https://cdn.katsklub.top/effects/lazy-loaf/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/lazy-loaf/loop.webp',
      introDuration: Duration(milliseconds: 12960),
    ),
    'lazy-loaf': ProfileEffectConfig(
      id: 'lazy-loaf',
      name: 'Lazy Loaf',
      introUrl: 'https://cdn.katsklub.top/effects/lazy-loaf/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/lazy-loaf/loop.webp',
      introDuration: Duration(milliseconds: 12960),
    ),
    'league_of_villains': ProfileEffectConfig(
      id: 'league_of_villains',
      name: 'League of Villains',
      introUrl: 'https://cdn.katsklub.top/effects/league-of-villains/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/league-of-villains/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'league-of-villains': ProfileEffectConfig(
      id: 'league-of-villains',
      name: 'League of Villains',
      introUrl: 'https://cdn.katsklub.top/effects/league-of-villains/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/league-of-villains/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'lightsaber_mastery_blue': ProfileEffectConfig(
      id: 'lightsaber_mastery_blue',
      name: 'Lightsaber Mastery Blue',
      introUrl: 'https://cdn.katsklub.top/effects/lightsaber-mastery-blue/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/lightsaber-mastery-blue/loop.webp',
      introDuration: Duration(milliseconds: 4981),
    ),
    'lightsaber-mastery-blue': ProfileEffectConfig(
      id: 'lightsaber-mastery-blue',
      name: 'Lightsaber Mastery Blue',
      introUrl: 'https://cdn.katsklub.top/effects/lightsaber-mastery-blue/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/lightsaber-mastery-blue/loop.webp',
      introDuration: Duration(milliseconds: 4981),
    ),
    'lightsaber_mastery_green': ProfileEffectConfig(
      id: 'lightsaber_mastery_green',
      name: 'Lightsaber Mastery Green',
      introUrl: 'https://cdn.katsklub.top/effects/lightsaber-mastery-green/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/lightsaber-mastery-green/loop.webp',
      introDuration: Duration(milliseconds: 4981),
    ),
    'lightsaber-mastery-green': ProfileEffectConfig(
      id: 'lightsaber-mastery-green',
      name: 'Lightsaber Mastery Green',
      introUrl: 'https://cdn.katsklub.top/effects/lightsaber-mastery-green/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/lightsaber-mastery-green/loop.webp',
      introDuration: Duration(milliseconds: 4981),
    ),
    'magic_hearts_blue': ProfileEffectConfig(
      id: 'magic_hearts_blue',
      name: 'Magic Hearts Blue',
      introUrl: 'https://cdn.katsklub.top/effects/magic-hearts-blue/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/magic-hearts-blue/loop.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'magic-hearts-blue': ProfileEffectConfig(
      id: 'magic-hearts-blue',
      name: 'Magic Hearts Blue',
      introUrl: 'https://cdn.katsklub.top/effects/magic-hearts-blue/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/magic-hearts-blue/loop.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'magic_hearts_gold': ProfileEffectConfig(
      id: 'magic_hearts_gold',
      name: 'Magic Hearts Gold',
      introUrl: 'https://cdn.katsklub.top/effects/magic-hearts-gold/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/magic-hearts-gold/loop.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'magic-hearts-gold': ProfileEffectConfig(
      id: 'magic-hearts-gold',
      name: 'Magic Hearts Gold',
      introUrl: 'https://cdn.katsklub.top/effects/magic-hearts-gold/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/magic-hearts-gold/loop.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'magic_mists': ProfileEffectConfig(
      id: 'magic_mists',
      name: 'Magic Mists',
      introUrl: 'https://cdn.katsklub.top/effects/magic-mists/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/magic-mists/loop.webp',
      introDuration: Duration(milliseconds: 3901),
    ),
    'magic-mists': ProfileEffectConfig(
      id: 'magic-mists',
      name: 'Magic Mists',
      introUrl: 'https://cdn.katsklub.top/effects/magic-mists/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/magic-mists/loop.webp',
      introDuration: Duration(milliseconds: 3901),
    ),
    'magical_girl_energy': ProfileEffectConfig(
      id: 'magical_girl_energy',
      name: 'Magical Girl Energy',
      introUrl: 'https://cdn.katsklub.top/effects/magical-girl-energy/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/magical-girl-energy/loop.webp',
      introDuration: Duration(milliseconds: 4981),
    ),
    'magical-girl-energy': ProfileEffectConfig(
      id: 'magical-girl-energy',
      name: 'Magical Girl Energy',
      introUrl: 'https://cdn.katsklub.top/effects/magical-girl-energy/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/magical-girl-energy/loop.webp',
      introDuration: Duration(milliseconds: 4981),
    ),
    'nature_is_healing': ProfileEffectConfig(
      id: 'nature_is_healing',
      name: 'Nature Is Healing',
      introUrl: 'https://cdn.katsklub.top/effects/nature-is-healing/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/nature-is-healing/loop.webp',
      introDuration: Duration(milliseconds: 3984),
    ),
    'nature-is-healing': ProfileEffectConfig(
      id: 'nature-is-healing',
      name: 'Nature Is Healing',
      introUrl: 'https://cdn.katsklub.top/effects/nature-is-healing/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/nature-is-healing/loop.webp',
      introDuration: Duration(milliseconds: 3984),
    ),
    'ningning': ProfileEffectConfig(
      id: 'ningning',
      name: 'Ningning',
      introUrl: 'https://cdn.katsklub.top/effects/ningning/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/ningning/loop.webp',
      introDuration: Duration(milliseconds: 3238),
    ),
    'nom_kitty_crunch': ProfileEffectConfig(
      id: 'nom_kitty_crunch',
      name: 'Nom Kitty Crunch',
      introUrl: 'https://cdn.katsklub.top/effects/nom-kitty-crunch/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/nom-kitty-crunch/loop.webp',
      introDuration: Duration(milliseconds: 4080),
    ),
    'nom-kitty-crunch': ProfileEffectConfig(
      id: 'nom-kitty-crunch',
      name: 'Nom Kitty Crunch',
      introUrl: 'https://cdn.katsklub.top/effects/nom-kitty-crunch/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/nom-kitty-crunch/loop.webp',
      introDuration: Duration(milliseconds: 4080),
    ),
    'pancake_pals': ProfileEffectConfig(
      id: 'pancake_pals',
      name: 'Pancake Pals',
      introUrl: 'https://cdn.katsklub.top/effects/pancake-pals/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/pancake-pals/loop.webp',
      introDuration: Duration(milliseconds: 1716),
    ),
    'pancake-pals': ProfileEffectConfig(
      id: 'pancake-pals',
      name: 'Pancake Pals',
      introUrl: 'https://cdn.katsklub.top/effects/pancake-pals/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/pancake-pals/loop.webp',
      introDuration: Duration(milliseconds: 1716),
    ),
    'power_surge_fuchsia': ProfileEffectConfig(
      id: 'power_surge_fuchsia',
      name: 'Power Surge Fuchsia',
      introUrl: 'https://cdn.katsklub.top/effects/power-surge-fuchsia/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/power-surge-fuchsia/loop.webp',
      introDuration: Duration(milliseconds: 2400),
    ),
    'power-surge-fuchsia': ProfileEffectConfig(
      id: 'power-surge-fuchsia',
      name: 'Power Surge Fuchsia',
      introUrl: 'https://cdn.katsklub.top/effects/power-surge-fuchsia/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/power-surge-fuchsia/loop.webp',
      introDuration: Duration(milliseconds: 2400),
    ),
    'power_surge_green': ProfileEffectConfig(
      id: 'power_surge_green',
      name: 'Power Surge Green',
      introUrl: 'https://cdn.katsklub.top/effects/power-surge-green/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/power-surge-green/loop.webp',
      introDuration: Duration(milliseconds: 2400),
    ),
    'power-surge-green': ProfileEffectConfig(
      id: 'power-surge-green',
      name: 'Power Surge Green',
      introUrl: 'https://cdn.katsklub.top/effects/power-surge-green/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/power-surge-green/loop.webp',
      introDuration: Duration(milliseconds: 2400),
    ),
    'roses_galore_blue': ProfileEffectConfig(
      id: 'roses_galore_blue',
      name: 'Roses Galore Blue',
      introUrl: 'https://cdn.katsklub.top/effects/roses-galore-blue/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/roses-galore-blue/loop.webp',
      introDuration: Duration(milliseconds: 2517),
    ),
    'roses-galore-blue': ProfileEffectConfig(
      id: 'roses-galore-blue',
      name: 'Roses Galore Blue',
      introUrl: 'https://cdn.katsklub.top/effects/roses-galore-blue/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/roses-galore-blue/loop.webp',
      introDuration: Duration(milliseconds: 2517),
    ),
    'roses_galore_red': ProfileEffectConfig(
      id: 'roses_galore_red',
      name: 'Roses Galore Red',
      introUrl: 'https://cdn.katsklub.top/effects/roses-galore-red/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/roses-galore-red/loop.webp',
      introDuration: Duration(milliseconds: 4720),
    ),
    'roses-galore-red': ProfileEffectConfig(
      id: 'roses-galore-red',
      name: 'Roses Galore Red',
      introUrl: 'https://cdn.katsklub.top/effects/roses-galore-red/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/roses-galore-red/loop.webp',
      introDuration: Duration(milliseconds: 4720),
    ),
    'ruby_photo_card': ProfileEffectConfig(
      id: 'ruby_photo_card',
      name: 'Ruby Photo Card',
      introUrl: 'https://cdn.katsklub.top/effects/ruby-photo-card/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/ruby-photo-card/loop.webp',
      introDuration: Duration(milliseconds: 3984),
    ),
    'ruby-photo-card': ProfileEffectConfig(
      id: 'ruby-photo-card',
      name: 'Ruby Photo Card',
      introUrl: 'https://cdn.katsklub.top/effects/ruby-photo-card/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/ruby-photo-card/loop.webp',
      introDuration: Duration(milliseconds: 3984),
    ),
    'science_victory': ProfileEffectConfig(
      id: 'science_victory',
      name: 'Science Victory',
      introUrl: 'https://cdn.katsklub.top/effects/science-victory/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/science-victory/loop.webp',
      introDuration: Duration(milliseconds: 4981),
    ),
    'science-victory': ProfileEffectConfig(
      id: 'science-victory',
      name: 'Science Victory',
      introUrl: 'https://cdn.katsklub.top/effects/science-victory/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/science-victory/loop.webp',
      introDuration: Duration(milliseconds: 4981),
    ),
    'shatter_blue': ProfileEffectConfig(
      id: 'shatter_blue',
      name: 'Shatter Blue',
      introUrl: 'https://cdn.katsklub.top/effects/shatter-blue/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/shatter-blue/loop.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'shatter-blue': ProfileEffectConfig(
      id: 'shatter-blue',
      name: 'Shatter Blue',
      introUrl: 'https://cdn.katsklub.top/effects/shatter-blue/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/shatter-blue/loop.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'shatter_purple': ProfileEffectConfig(
      id: 'shatter_purple',
      name: 'Shatter Purple',
      introUrl: 'https://cdn.katsklub.top/effects/shatter-purple/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/shatter-purple/loop.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'shatter-purple': ProfileEffectConfig(
      id: 'shatter-purple',
      name: 'Shatter Purple',
      introUrl: 'https://cdn.katsklub.top/effects/shatter-purple/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/shatter-purple/loop.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'shuriken_strike_blue': ProfileEffectConfig(
      id: 'shuriken_strike_blue',
      name: 'Shuriken Strike Blue',
      introUrl: 'https://cdn.katsklub.top/effects/shuriken-strike-blue/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/shuriken-strike-blue/loop.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'shuriken-strike-blue': ProfileEffectConfig(
      id: 'shuriken-strike-blue',
      name: 'Shuriken Strike Blue',
      introUrl: 'https://cdn.katsklub.top/effects/shuriken-strike-blue/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/shuriken-strike-blue/loop.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'shuriken_strike_yellow': ProfileEffectConfig(
      id: 'shuriken_strike_yellow',
      name: 'Shuriken Strike Yellow',
      introUrl: 'https://cdn.katsklub.top/effects/shuriken-strike-yellow/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/shuriken-strike-yellow/loop.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'shuriken-strike-yellow': ProfileEffectConfig(
      id: 'shuriken-strike-yellow',
      name: 'Shuriken Strike Yellow',
      introUrl: 'https://cdn.katsklub.top/effects/shuriken-strike-yellow/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/shuriken-strike-yellow/loop.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'starfall_tides': ProfileEffectConfig(
      id: 'starfall_tides',
      name: 'Starfall Tides',
      introUrl: 'https://cdn.katsklub.top/effects/starfall-tides/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/starfall-tides/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'starfall-tides': ProfileEffectConfig(
      id: 'starfall-tides',
      name: 'Starfall Tides',
      introUrl: 'https://cdn.katsklub.top/effects/starfall-tides/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/starfall-tides/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'starfall_tides_nightshade': ProfileEffectConfig(
      id: 'starfall_tides_nightshade',
      name: 'Starfall Tides Nightshade',
      introUrl: 'https://cdn.katsklub.top/effects/starfall-tides-nightshade/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/starfall-tides-nightshade/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'starfall-tides-nightshade': ProfileEffectConfig(
      id: 'starfall-tides-nightshade',
      name: 'Starfall Tides Nightshade',
      introUrl: 'https://cdn.katsklub.top/effects/starfall-tides-nightshade/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/starfall-tides-nightshade/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'starfall_tides_rose': ProfileEffectConfig(
      id: 'starfall_tides_rose',
      name: 'Starfall Tides Rose',
      introUrl: 'https://cdn.katsklub.top/effects/starfall-tides-rose/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/starfall-tides-rose/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'starfall-tides-rose': ProfileEffectConfig(
      id: 'starfall-tides-rose',
      name: 'Starfall Tides Rose',
      introUrl: 'https://cdn.katsklub.top/effects/starfall-tides-rose/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/starfall-tides-rose/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'starfall_tides_void': ProfileEffectConfig(
      id: 'starfall_tides_void',
      name: 'Starfall Tides Void',
      introUrl: 'https://cdn.katsklub.top/effects/starfall-tides-void/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/starfall-tides-void/loop.webp',
      introDuration: Duration(milliseconds: 4800),
    ),
    'starfall-tides-void': ProfileEffectConfig(
      id: 'starfall-tides-void',
      name: 'Starfall Tides Void',
      introUrl: 'https://cdn.katsklub.top/effects/starfall-tides-void/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/starfall-tides-void/loop.webp',
      introDuration: Duration(milliseconds: 4800),
    ),
    'sushi_mania_blue': ProfileEffectConfig(
      id: 'sushi_mania_blue',
      name: 'Sushi Mania Blue',
      introUrl: 'https://cdn.katsklub.top/effects/sushi-mania-blue/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/sushi-mania-blue/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'sushi-mania-blue': ProfileEffectConfig(
      id: 'sushi-mania-blue',
      name: 'Sushi Mania Blue',
      introUrl: 'https://cdn.katsklub.top/effects/sushi-mania-blue/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/sushi-mania-blue/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'sushi_mania_green': ProfileEffectConfig(
      id: 'sushi_mania_green',
      name: 'Sushi Mania Green',
      introUrl: 'https://cdn.katsklub.top/effects/sushi-mania-green/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/sushi-mania-green/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'sushi-mania-green': ProfileEffectConfig(
      id: 'sushi-mania-green',
      name: 'Sushi Mania Green',
      introUrl: 'https://cdn.katsklub.top/effects/sushi-mania-green/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/sushi-mania-green/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'sushi_mania_pink': ProfileEffectConfig(
      id: 'sushi_mania_pink',
      name: 'Sushi Mania Pink',
      introUrl: 'https://cdn.katsklub.top/effects/sushi-mania-pink/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/sushi-mania-pink/loop.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'sushi-mania-pink': ProfileEffectConfig(
      id: 'sushi-mania-pink',
      name: 'Sushi Mania Pink',
      introUrl: 'https://cdn.katsklub.top/effects/sushi-mania-pink/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/sushi-mania-pink/loop.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'sushi_mania_yellow': ProfileEffectConfig(
      id: 'sushi_mania_yellow',
      name: 'Sushi Mania Yellow',
      introUrl: 'https://cdn.katsklub.top/effects/sushi-mania-yellow/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/sushi-mania-yellow/loop.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'sushi-mania-yellow': ProfileEffectConfig(
      id: 'sushi-mania-yellow',
      name: 'Sushi Mania Yellow',
      introUrl: 'https://cdn.katsklub.top/effects/sushi-mania-yellow/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/sushi-mania-yellow/loop.webp',
      introDuration: Duration(milliseconds: 2880),
    ),
    'sweet_copium': ProfileEffectConfig(
      id: 'sweet_copium',
      name: 'Sweet Copium',
      introUrl: 'https://cdn.katsklub.top/effects/sweet-copium/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/sweet-copium/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'sweet-copium': ProfileEffectConfig(
      id: 'sweet-copium',
      name: 'Sweet Copium',
      introUrl: 'https://cdn.katsklub.top/effects/sweet-copium/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/sweet-copium/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'tumbleweeds': ProfileEffectConfig(
      id: 'tumbleweeds',
      name: 'Tumbleweeds',
      introUrl: 'https://cdn.katsklub.top/effects/tumbleweeds/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/tumbleweeds/loop.webp',
      introDuration: Duration(milliseconds: 3600),
    ),
    'winter': ProfileEffectConfig(
      id: 'winter',
      name: 'Winter',
      introUrl: 'https://cdn.katsklub.top/effects/winter/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/winter/loop.webp',
      introDuration: Duration(milliseconds: 3238),
    ),
    'wishful_beginnings': ProfileEffectConfig(
      id: 'wishful_beginnings',
      name: 'Wishful Beginnings',
      introUrl: 'https://cdn.katsklub.top/effects/wishful-beginnings/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/wishful-beginnings/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'wishful-beginnings': ProfileEffectConfig(
      id: 'wishful-beginnings',
      name: 'Wishful Beginnings',
      introUrl: 'https://cdn.katsklub.top/effects/wishful-beginnings/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/wishful-beginnings/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),

'angelic_intervention': ProfileEffectConfig(
      id: 'angelic_intervention',
      name: 'Angelic Intervention',
      introUrl: 'https://cdn.katsklub.top/effects/angelic-intervention/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/angelic-intervention/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'angelic-intervention': ProfileEffectConfig(
      id: 'angelic-intervention',
      name: 'Angelic Intervention',
      introUrl: 'https://cdn.katsklub.top/effects/angelic-intervention/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/angelic-intervention/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'fae_trickery': ProfileEffectConfig(
      id: 'fae_trickery',
      name: 'Fae Trickery',
      introUrl: 'https://cdn.katsklub.top/effects/fae-trickery/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/fae-trickery/loop.webp',
      introDuration: Duration(milliseconds: 3984),
    ),
    'fae-trickery': ProfileEffectConfig(
      id: 'fae-trickery',
      name: 'Fae Trickery',
      introUrl: 'https://cdn.katsklub.top/effects/fae-trickery/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/fae-trickery/loop.webp',
      introDuration: Duration(milliseconds: 3984),
    ),
    'zombie_apocalypse': ProfileEffectConfig(
      id: 'zombie_apocalypse',
      name: 'Zombie Apocalypse',
      introUrl: 'https://cdn.katsklub.top/effects/zombie-apocalypse/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/zombie-apocalypse/loop.webp',
      introDuration: Duration(milliseconds: 3984),
    ),
    'zombie-apocalypse': ProfileEffectConfig(
      id: 'zombie-apocalypse',
      name: 'Zombie Apocalypse',
      introUrl: 'https://cdn.katsklub.top/effects/zombie-apocalypse/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/zombie-apocalypse/loop.webp',
      introDuration: Duration(milliseconds: 3984),
    ),
    'dragon_s_approach': ProfileEffectConfig(
      id: 'dragon_s_approach',
      name: 'Dragon\'s Approach',
      introUrl: 'https://cdn.katsklub.top/effects/dragon-s-approach/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/dragon-s-approach/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'dragon-s-approach': ProfileEffectConfig(
      id: 'dragon-s-approach',
      name: 'Dragon\'s Approach',
      introUrl: 'https://cdn.katsklub.top/effects/dragon-s-approach/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/dragon-s-approach/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'primal_hunger': ProfileEffectConfig(
      id: 'primal_hunger',
      name: 'Primal Hunger',
      introUrl: 'https://cdn.katsklub.top/effects/primal-hunger/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/primal-hunger/loop.webp',
      introDuration: Duration(milliseconds: 3984),
    ),
    'primal-hunger': ProfileEffectConfig(
      id: 'primal-hunger',
      name: 'Primal Hunger',
      introUrl: 'https://cdn.katsklub.top/effects/primal-hunger/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/primal-hunger/loop.webp',
      introDuration: Duration(milliseconds: 3984),
    ),
    'bonsai_eternity': ProfileEffectConfig(
      id: 'bonsai_eternity',
      name: 'Bonsai Eternity',
      introUrl: 'https://cdn.katsklub.top/effects/bonsai-eternity/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/bonsai-eternity/loop.webp',
      introDuration: Duration(milliseconds: 6059),
    ),
    'bonsai-eternity': ProfileEffectConfig(
      id: 'bonsai-eternity',
      name: 'Bonsai Eternity',
      introUrl: 'https://cdn.katsklub.top/effects/bonsai-eternity/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/bonsai-eternity/loop.webp',
      introDuration: Duration(milliseconds: 6059),
    ),
    'shadow_strike': ProfileEffectConfig(
      id: 'shadow_strike',
      name: 'Shadow Strike',
      introUrl: 'https://cdn.katsklub.top/effects/shadow-strike/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/shadow-strike/loop.webp',
      introDuration: Duration(milliseconds: 5312),
    ),
    'shadow-strike': ProfileEffectConfig(
      id: 'shadow-strike',
      name: 'Shadow Strike',
      introUrl: 'https://cdn.katsklub.top/effects/shadow-strike/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/shadow-strike/loop.webp',
      introDuration: Duration(milliseconds: 5312),
    ),
    'zen_garden': ProfileEffectConfig(
      id: 'zen_garden',
      name: 'Zen Garden',
      introUrl: 'https://cdn.katsklub.top/effects/zen-garden/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/zen-garden/loop.webp',
      introDuration: Duration(milliseconds: 4982),
    ),
    'zen-garden': ProfileEffectConfig(
      id: 'zen-garden',
      name: 'Zen Garden',
      introUrl: 'https://cdn.katsklub.top/effects/zen-garden/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/zen-garden/loop.webp',
      introDuration: Duration(milliseconds: 4982),
    ),
    'lots_of_bubbles': ProfileEffectConfig(
      id: 'lots_of_bubbles',
      name: 'Lots of bubbles',
      introUrl: 'https://cdn.katsklub.top/effects/lots-of-bubbles/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/lots-of-bubbles/loop.webp',
      introDuration: Duration(milliseconds: 4316),
    ),
    'lots-of-bubbles': ProfileEffectConfig(
      id: 'lots-of-bubbles',
      name: 'Lots of bubbles',
      introUrl: 'https://cdn.katsklub.top/effects/lots-of-bubbles/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/lots-of-bubbles/loop.webp',
      introDuration: Duration(milliseconds: 4316),
    ),
    'firefly_meadow': ProfileEffectConfig(
      id: 'firefly_meadow',
      name: 'Firefly Meadow',
      introUrl: 'https://cdn.katsklub.top/effects/firefly-meadow/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/firefly-meadow/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'firefly-meadow': ProfileEffectConfig(
      id: 'firefly-meadow',
      name: 'Firefly Meadow',
      introUrl: 'https://cdn.katsklub.top/effects/firefly-meadow/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/firefly-meadow/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'the_same_duck': ProfileEffectConfig(
      id: 'the_same_duck',
      name: 'the same duck',
      introUrl: 'https://cdn.katsklub.top/effects/the-same-duck/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/the-same-duck/loop.webp',
      introDuration: Duration(milliseconds: 5063),
    ),
    'the-same-duck': ProfileEffectConfig(
      id: 'the-same-duck',
      name: 'the same duck',
      introUrl: 'https://cdn.katsklub.top/effects/the-same-duck/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/the-same-duck/loop.webp',
      introDuration: Duration(milliseconds: 5063),
    ),
    'join_the_alliance': ProfileEffectConfig(
      id: 'join_the_alliance',
      name: 'Join the Alliance',
      introUrl: 'https://cdn.katsklub.top/effects/join-the-alliance/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/join-the-alliance/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'join-the-alliance': ProfileEffectConfig(
      id: 'join-the-alliance',
      name: 'Join the Alliance',
      introUrl: 'https://cdn.katsklub.top/effects/join-the-alliance/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/join-the-alliance/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'duchess_astro': ProfileEffectConfig(
      id: 'duchess_astro',
      name: 'Duchess Astro',
      introUrl: 'https://cdn.katsklub.top/effects/duchess-astro/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/duchess-astro/loop.webp',
      introDuration: Duration(milliseconds: 4566),
    ),
    'duchess-astro': ProfileEffectConfig(
      id: 'duchess-astro',
      name: 'Duchess Astro',
      introUrl: 'https://cdn.katsklub.top/effects/duchess-astro/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/duchess-astro/loop.webp',
      introDuration: Duration(milliseconds: 4566),
    ),
    'critical_damage': ProfileEffectConfig(
      id: 'critical_damage',
      name: 'Critical Damage',
      introUrl: 'https://cdn.katsklub.top/effects/critical-damage/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/critical-damage/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'critical-damage': ProfileEffectConfig(
      id: 'critical-damage',
      name: 'Critical Damage',
      introUrl: 'https://cdn.katsklub.top/effects/critical-damage/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/critical-damage/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'titan_vs_astro': ProfileEffectConfig(
      id: 'titan_vs_astro',
      name: 'Titan vs Astro',
      introUrl: 'https://cdn.katsklub.top/effects/titan-vs-astro/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/titan-vs-astro/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'titan-vs-astro': ProfileEffectConfig(
      id: 'titan-vs-astro',
      name: 'Titan vs Astro',
      introUrl: 'https://cdn.katsklub.top/effects/titan-vs-astro/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/titan-vs-astro/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'skibidi_toilets': ProfileEffectConfig(
      id: 'skibidi_toilets',
      name: 'Skibidi Toilets',
      introUrl: 'https://cdn.katsklub.top/effects/skibidi-toilets/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/skibidi-toilets/loop.webp',
      introDuration: Duration(milliseconds: 4150),
    ),
    'skibidi-toilets': ProfileEffectConfig(
      id: 'skibidi-toilets',
      name: 'Skibidi Toilets',
      introUrl: 'https://cdn.katsklub.top/effects/skibidi-toilets/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/skibidi-toilets/loop.webp',
      introDuration: Duration(milliseconds: 4150),
    ),
    'spirit_blossom_springs': ProfileEffectConfig(
      id: 'spirit_blossom_springs',
      name: 'Spirit Blossom Springs',
      introUrl: 'https://cdn.katsklub.top/effects/spirit-blossom-springs/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/spirit-blossom-springs/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'spirit-blossom-springs': ProfileEffectConfig(
      id: 'spirit-blossom-springs',
      name: 'Spirit Blossom Springs',
      introUrl: 'https://cdn.katsklub.top/effects/spirit-blossom-springs/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/spirit-blossom-springs/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'yunara_s_aion_er_na': ProfileEffectConfig(
      id: 'yunara_s_aion_er_na',
      name: 'Yunara\'s Aion Er\'na',
      introUrl: 'https://cdn.katsklub.top/effects/yunara-s-aion-er-na/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/yunara-s-aion-er-na/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'yunara-s-aion-er-na': ProfileEffectConfig(
      id: 'yunara-s-aion-er-na',
      name: 'Yunara\'s Aion Er\'na',
      introUrl: 'https://cdn.katsklub.top/effects/yunara-s-aion-er-na/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/yunara-s-aion-er-na/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'ahri_s_floating_ducks': ProfileEffectConfig(
      id: 'ahri_s_floating_ducks',
      name: 'Ahri\'s Floating Ducks',
      introUrl: 'https://cdn.katsklub.top/effects/ahri-s-floating-ducks/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/ahri-s-floating-ducks/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'ahri-s-floating-ducks': ProfileEffectConfig(
      id: 'ahri-s-floating-ducks',
      name: 'Ahri\'s Floating Ducks',
      introUrl: 'https://cdn.katsklub.top/effects/ahri-s-floating-ducks/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/ahri-s-floating-ducks/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'silver_surfer': ProfileEffectConfig(
      id: 'silver_surfer',
      name: 'Silver Surfer',
      introUrl: 'https://cdn.katsklub.top/effects/silver-surfer/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/silver-surfer/loop.webp',
      introDuration: Duration(milliseconds: 3984),
    ),
    'silver-surfer': ProfileEffectConfig(
      id: 'silver-surfer',
      name: 'Silver Surfer',
      introUrl: 'https://cdn.katsklub.top/effects/silver-surfer/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/silver-surfer/loop.webp',
      introDuration: Duration(milliseconds: 3984),
    ),
    'the_fantastic_four': ProfileEffectConfig(
      id: 'the_fantastic_four',
      name: 'The Fantastic Four',
      introUrl: 'https://cdn.katsklub.top/effects/the-fantastic-four/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/the-fantastic-four/loop.webp',
      introDuration: Duration(milliseconds: 3072),
    ),
    'the-fantastic-four': ProfileEffectConfig(
      id: 'the-fantastic-four',
      name: 'The Fantastic Four',
      introUrl: 'https://cdn.katsklub.top/effects/the-fantastic-four/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/the-fantastic-four/loop.webp',
      introDuration: Duration(milliseconds: 3072),
    ),
    'galactus': ProfileEffectConfig(
      id: 'galactus',
      name: 'Galactus',
      introUrl: 'https://cdn.katsklub.top/effects/galactus/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/galactus/loop.webp',
      introDuration: Duration(milliseconds: 4982),
    ),
    'gomah': ProfileEffectConfig(
      id: 'gomah',
      name: 'Gomah',
      introUrl: 'https://cdn.katsklub.top/effects/gomah/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/gomah/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'mini_goku': ProfileEffectConfig(
      id: 'mini_goku',
      name: 'Mini Goku',
      introUrl: 'https://cdn.katsklub.top/effects/mini-goku/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/mini-goku/loop.webp',
      introDuration: Duration(milliseconds: 2573),
    ),
    'mini-goku': ProfileEffectConfig(
      id: 'mini-goku',
      name: 'Mini Goku',
      introUrl: 'https://cdn.katsklub.top/effects/mini-goku/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/mini-goku/loop.webp',
      introDuration: Duration(milliseconds: 2573),
    ),
    'mini_vegeta': ProfileEffectConfig(
      id: 'mini_vegeta',
      name: 'Mini Vegeta',
      introUrl: 'https://cdn.katsklub.top/effects/mini-vegeta/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/mini-vegeta/loop.webp',
      introDuration: Duration(milliseconds: 4982),
    ),
    'mini-vegeta': ProfileEffectConfig(
      id: 'mini-vegeta',
      name: 'Mini Vegeta',
      introUrl: 'https://cdn.katsklub.top/effects/mini-vegeta/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/mini-vegeta/loop.webp',
      introDuration: Duration(milliseconds: 4982),
    ),
    'mini_piccolo': ProfileEffectConfig(
      id: 'mini_piccolo',
      name: 'Mini Piccolo',
      introUrl: 'https://cdn.katsklub.top/effects/mini-piccolo/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/mini-piccolo/loop.webp',
      introDuration: Duration(milliseconds: 2740),
    ),
    'mini-piccolo': ProfileEffectConfig(
      id: 'mini-piccolo',
      name: 'Mini Piccolo',
      introUrl: 'https://cdn.katsklub.top/effects/mini-piccolo/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/mini-piccolo/loop.webp',
      introDuration: Duration(milliseconds: 2740),
    ),
    'hehe_so_random_xp': ProfileEffectConfig(
      id: 'hehe_so_random_xp',
      name: 'hehe so random xP',
      introUrl: 'https://cdn.katsklub.top/effects/hehe-so-random-xp/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/hehe-so-random-xp/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'hehe-so-random-xp': ProfileEffectConfig(
      id: 'hehe-so-random-xp',
      name: 'hehe so random xP',
      introUrl: 'https://cdn.katsklub.top/effects/hehe-so-random-xp/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/hehe-so-random-xp/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'rawr_xd_splash': ProfileEffectConfig(
      id: 'rawr_xd_splash',
      name: 'Rawr xD Splash',
      introUrl: 'https://cdn.katsklub.top/effects/rawr-xd-splash/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/rawr-xd-splash/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'rawr-xd-splash': ProfileEffectConfig(
      id: 'rawr-xd-splash',
      name: 'Rawr xD Splash',
      introUrl: 'https://cdn.katsklub.top/effects/rawr-xd-splash/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/rawr-xd-splash/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'kawaii_clouds_blue': ProfileEffectConfig(
      id: 'kawaii_clouds_blue',
      name: 'Kawaii Clouds (Blue)',
      introUrl: 'https://cdn.katsklub.top/effects/kawaii-clouds-blue/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/kawaii-clouds-blue/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'kawaii-clouds-blue': ProfileEffectConfig(
      id: 'kawaii-clouds-blue',
      name: 'Kawaii Clouds (Blue)',
      introUrl: 'https://cdn.katsklub.top/effects/kawaii-clouds-blue/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/kawaii-clouds-blue/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'spring_rain': ProfileEffectConfig(
      id: 'spring_rain',
      name: 'Spring Rain',
      introUrl: 'https://cdn.katsklub.top/effects/spring-rain/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/spring-rain/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'spring-rain': ProfileEffectConfig(
      id: 'spring-rain',
      name: 'Spring Rain',
      introUrl: 'https://cdn.katsklub.top/effects/spring-rain/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/spring-rain/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'butterfly_haven': ProfileEffectConfig(
      id: 'butterfly_haven',
      name: 'Butterfly Haven',
      introUrl: 'https://cdn.katsklub.top/effects/butterfly-haven/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/butterfly-haven/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'butterfly-haven': ProfileEffectConfig(
      id: 'butterfly-haven',
      name: 'Butterfly Haven',
      introUrl: 'https://cdn.katsklub.top/effects/butterfly-haven/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/butterfly-haven/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'wind_chime': ProfileEffectConfig(
      id: 'wind_chime',
      name: 'Wind Chime',
      introUrl: 'https://cdn.katsklub.top/effects/wind-chime/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/wind-chime/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'wind-chime': ProfileEffectConfig(
      id: 'wind-chime',
      name: 'Wind Chime',
      introUrl: 'https://cdn.katsklub.top/effects/wind-chime/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/wind-chime/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'blast_off': ProfileEffectConfig(
      id: 'blast_off',
      name: 'Blast Off',
      introUrl: 'https://cdn.katsklub.top/effects/blast-off/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/blast-off/loop.webp',
      introDuration: Duration(milliseconds: 2016),
    ),
    'blast-off': ProfileEffectConfig(
      id: 'blast-off',
      name: 'Blast Off',
      introUrl: 'https://cdn.katsklub.top/effects/blast-off/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/blast-off/loop.webp',
      introDuration: Duration(milliseconds: 2016),
    ),
    'starfall_rings': ProfileEffectConfig(
      id: 'starfall_rings',
      name: 'Starfall Rings',
      introUrl: 'https://cdn.katsklub.top/effects/starfall-rings/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/starfall-rings/loop.webp',
      introDuration: Duration(milliseconds: 4648),
    ),
    'starfall-rings': ProfileEffectConfig(
      id: 'starfall-rings',
      name: 'Starfall Rings',
      introUrl: 'https://cdn.katsklub.top/effects/starfall-rings/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/starfall-rings/loop.webp',
      introDuration: Duration(milliseconds: 4648),
    ),
    'liquid_moonlight': ProfileEffectConfig(
      id: 'liquid_moonlight',
      name: 'Liquid Moonlight',
      introUrl: 'https://cdn.katsklub.top/effects/liquid-moonlight/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/liquid-moonlight/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'liquid-moonlight': ProfileEffectConfig(
      id: 'liquid-moonlight',
      name: 'Liquid Moonlight',
      introUrl: 'https://cdn.katsklub.top/effects/liquid-moonlight/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/liquid-moonlight/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'moonlit_crystals': ProfileEffectConfig(
      id: 'moonlit_crystals',
      name: 'Moonlit Crystals',
      introUrl: 'https://cdn.katsklub.top/effects/moonlit-crystals/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/moonlit-crystals/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'moonlit-crystals': ProfileEffectConfig(
      id: 'moonlit-crystals',
      name: 'Moonlit Crystals',
      introUrl: 'https://cdn.katsklub.top/effects/moonlit-crystals/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/moonlit-crystals/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'loot_shower': ProfileEffectConfig(
      id: 'loot_shower',
      name: 'Loot Shower',
      introUrl: 'https://cdn.katsklub.top/effects/loot-shower/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/loot-shower/loop.webp',
      introDuration: Duration(milliseconds: 4982),
    ),
    'loot-shower': ProfileEffectConfig(
      id: 'loot-shower',
      name: 'Loot Shower',
      introUrl: 'https://cdn.katsklub.top/effects/loot-shower/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/loot-shower/loop.webp',
      introDuration: Duration(milliseconds: 4982),
    ),
    'doin_the_robot': ProfileEffectConfig(
      id: 'doin_the_robot',
      name: 'Doin\' the robot',
      introUrl: 'https://cdn.katsklub.top/effects/doin-the-robot/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/doin-the-robot/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'doin-the-robot': ProfileEffectConfig(
      id: 'doin-the-robot',
      name: 'Doin\' the robot',
      introUrl: 'https://cdn.katsklub.top/effects/doin-the-robot/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/doin-the-robot/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'the_timekeeper': ProfileEffectConfig(
      id: 'the_timekeeper',
      name: 'The Timekeeper',
      introUrl: 'https://cdn.katsklub.top/effects/the-timekeeper/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/the-timekeeper/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'the-timekeeper': ProfileEffectConfig(
      id: 'the-timekeeper',
      name: 'The Timekeeper',
      introUrl: 'https://cdn.katsklub.top/effects/the-timekeeper/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/the-timekeeper/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'weeeee': ProfileEffectConfig(
      id: 'weeeee',
      name: 'WEEEEE~',
      introUrl: 'https://cdn.katsklub.top/effects/weeeee/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/weeeee/loop.webp',
      introDuration: Duration(milliseconds: 4984),
    ),
    'you_rang_treat': ProfileEffectConfig(
      id: 'you_rang_treat',
      name: 'You Rang? (Treat)',
      introUrl: 'https://cdn.katsklub.top/effects/you-rang-treat/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/you-rang-treat/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'you-rang-treat': ProfileEffectConfig(
      id: 'you-rang-treat',
      name: 'You Rang? (Treat)',
      introUrl: 'https://cdn.katsklub.top/effects/you-rang-treat/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/you-rang-treat/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'you_rang_trick': ProfileEffectConfig(
      id: 'you_rang_trick',
      name: 'You Rang? (Trick)',
      introUrl: 'https://cdn.katsklub.top/effects/you-rang-trick/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/you-rang-trick/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'you-rang-trick': ProfileEffectConfig(
      id: 'you-rang-trick',
      name: 'You Rang? (Trick)',
      introUrl: 'https://cdn.katsklub.top/effects/you-rang-trick/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/you-rang-trick/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'maple_mornings': ProfileEffectConfig(
      id: 'maple_mornings',
      name: 'Maple Mornings',
      introUrl: 'https://cdn.katsklub.top/effects/maple-mornings/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/maple-mornings/loop.webp',
      introDuration: Duration(milliseconds: 4981),
    ),
    'maple-mornings': ProfileEffectConfig(
      id: 'maple-mornings',
      name: 'Maple Mornings',
      introUrl: 'https://cdn.katsklub.top/effects/maple-mornings/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/maple-mornings/loop.webp',
      introDuration: Duration(milliseconds: 4981),
    ),
    'world_wide_web_treat': ProfileEffectConfig(
      id: 'world_wide_web_treat',
      name: 'World Wide Web (Treat)',
      introUrl: 'https://cdn.katsklub.top/effects/world-wide-web-treat/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/world-wide-web-treat/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'world-wide-web-treat': ProfileEffectConfig(
      id: 'world-wide-web-treat',
      name: 'World Wide Web (Treat)',
      introUrl: 'https://cdn.katsklub.top/effects/world-wide-web-treat/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/world-wide-web-treat/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'a_bit_batty_trick': ProfileEffectConfig(
      id: 'a_bit_batty_trick',
      name: 'A Bit Batty (Trick)',
      introUrl: 'https://cdn.katsklub.top/effects/a-bit-batty-trick/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/a-bit-batty-trick/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'a-bit-batty-trick': ProfileEffectConfig(
      id: 'a-bit-batty-trick',
      name: 'A Bit Batty (Trick)',
      introUrl: 'https://cdn.katsklub.top/effects/a-bit-batty-trick/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/a-bit-batty-trick/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'every_profile_is_a_stage_teal': ProfileEffectConfig(
      id: 'every_profile_is_a_stage_teal',
      name: 'Every Profile is a Stage (Teal)',
      introUrl: 'https://cdn.katsklub.top/effects/every-profile-is-a-stage-teal/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/every-profile-is-a-stage-teal/loop.webp',
      introDuration: Duration(milliseconds: 4067),
    ),
    'every-profile-is-a-stage-teal': ProfileEffectConfig(
      id: 'every-profile-is-a-stage-teal',
      name: 'Every Profile is a Stage (Teal)',
      introUrl: 'https://cdn.katsklub.top/effects/every-profile-is-a-stage-teal/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/every-profile-is-a-stage-teal/loop.webp',
      introDuration: Duration(milliseconds: 4067),
    ),
    'a_bit_batty_treat': ProfileEffectConfig(
      id: 'a_bit_batty_treat',
      name: 'A Bit Batty (Treat)',
      introUrl: 'https://cdn.katsklub.top/effects/a-bit-batty-treat/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/a-bit-batty-treat/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'a-bit-batty-treat': ProfileEffectConfig(
      id: 'a-bit-batty-treat',
      name: 'A Bit Batty (Treat)',
      introUrl: 'https://cdn.katsklub.top/effects/a-bit-batty-treat/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/a-bit-batty-treat/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'every_profile_is_a_stage_orange': ProfileEffectConfig(
      id: 'every_profile_is_a_stage_orange',
      name: 'Every Profile is a Stage (Orange)',
      introUrl: 'https://cdn.katsklub.top/effects/every-profile-is-a-stage-orange/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/every-profile-is-a-stage-orange/loop.webp',
      introDuration: Duration(milliseconds: 4067),
    ),
    'every-profile-is-a-stage-orange': ProfileEffectConfig(
      id: 'every-profile-is-a-stage-orange',
      name: 'Every Profile is a Stage (Orange)',
      introUrl: 'https://cdn.katsklub.top/effects/every-profile-is-a-stage-orange/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/every-profile-is-a-stage-orange/loop.webp',
      introDuration: Duration(milliseconds: 4067),
    ),
    'cozy_flower': ProfileEffectConfig(
      id: 'cozy_flower',
      name: 'Cozy Flower',
      introUrl: 'https://cdn.katsklub.top/effects/cozy-flower/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/cozy-flower/loop.webp',
      introDuration: Duration(milliseconds: 4981),
    ),
    'cozy-flower': ProfileEffectConfig(
      id: 'cozy-flower',
      name: 'Cozy Flower',
      introUrl: 'https://cdn.katsklub.top/effects/cozy-flower/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/cozy-flower/loop.webp',
      introDuration: Duration(milliseconds: 4981),
    ),
    'world_wide_web_trick': ProfileEffectConfig(
      id: 'world_wide_web_trick',
      name: 'World Wide Web (Trick)',
      introUrl: 'https://cdn.katsklub.top/effects/world-wide-web-trick/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/world-wide-web-trick/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'world-wide-web-trick': ProfileEffectConfig(
      id: 'world-wide-web-trick',
      name: 'World Wide Web (Trick)',
      introUrl: 'https://cdn.katsklub.top/effects/world-wide-web-trick/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/world-wide-web-trick/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'black_flash': ProfileEffectConfig(
      id: 'black_flash',
      name: 'Black Flash',
      introUrl: 'https://cdn.katsklub.top/effects/black-flash/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/black-flash/loop.webp',
      introDuration: Duration(milliseconds: 4402),
    ),
    'black-flash': ProfileEffectConfig(
      id: 'black-flash',
      name: 'Black Flash',
      introUrl: 'https://cdn.katsklub.top/effects/black-flash/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/black-flash/loop.webp',
      introDuration: Duration(milliseconds: 4402),
    ),
    'unlimited_void': ProfileEffectConfig(
      id: 'unlimited_void',
      name: 'Unlimited Void',
      introUrl: 'https://cdn.katsklub.top/effects/unlimited-void/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/unlimited-void/loop.webp',
      introDuration: Duration(milliseconds: 3190),
    ),
    'unlimited-void': ProfileEffectConfig(
      id: 'unlimited-void',
      name: 'Unlimited Void',
      introUrl: 'https://cdn.katsklub.top/effects/unlimited-void/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/unlimited-void/loop.webp',
      introDuration: Duration(milliseconds: 3190),
    ),
    'malevolent_shrine': ProfileEffectConfig(
      id: 'malevolent_shrine',
      name: 'Malevolent Shrine',
      introUrl: 'https://cdn.katsklub.top/effects/malevolent-shrine/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/malevolent-shrine/loop.webp',
      introDuration: Duration(milliseconds: 4235),
    ),
    'malevolent-shrine': ProfileEffectConfig(
      id: 'malevolent-shrine',
      name: 'Malevolent Shrine',
      introUrl: 'https://cdn.katsklub.top/effects/malevolent-shrine/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/malevolent-shrine/loop.webp',
      introDuration: Duration(milliseconds: 4235),
    ),
    'black_ops_7': ProfileEffectConfig(
      id: 'black_ops_7',
      name: 'Black Ops 7',
      introUrl: 'https://cdn.katsklub.top/effects/black-ops-7/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/black-ops-7/loop.webp',
      introDuration: Duration(milliseconds: 3904),
    ),
    'black-ops-7': ProfileEffectConfig(
      id: 'black-ops-7',
      name: 'Black Ops 7',
      introUrl: 'https://cdn.katsklub.top/effects/black-ops-7/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/black-ops-7/loop.webp',
      introDuration: Duration(milliseconds: 3904),
    ),
    'shattered_reality': ProfileEffectConfig(
      id: 'shattered_reality',
      name: 'Shattered Reality',
      introUrl: 'https://cdn.katsklub.top/effects/shattered-reality/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/shattered-reality/loop.webp',
      introDuration: Duration(milliseconds: 4982),
    ),
    'shattered-reality': ProfileEffectConfig(
      id: 'shattered-reality',
      name: 'Shattered Reality',
      introUrl: 'https://cdn.katsklub.top/effects/shattered-reality/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/shattered-reality/loop.webp',
      introDuration: Duration(milliseconds: 4982),
    ),
    'the_grid_fireworks': ProfileEffectConfig(
      id: 'the_grid_fireworks',
      name: 'The Grid Fireworks',
      introUrl: 'https://cdn.katsklub.top/effects/the-grid-fireworks/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/the-grid-fireworks/loop.webp',
      introDuration: Duration(milliseconds: 3071),
    ),
    'the-grid-fireworks': ProfileEffectConfig(
      id: 'the-grid-fireworks',
      name: 'The Grid Fireworks',
      introUrl: 'https://cdn.katsklub.top/effects/the-grid-fireworks/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/the-grid-fireworks/loop.webp',
      introDuration: Duration(milliseconds: 3071),
    ),
    'light_cycles': ProfileEffectConfig(
      id: 'light_cycles',
      name: 'Light Cycles',
      introUrl: 'https://cdn.katsklub.top/effects/light-cycles/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/light-cycles/loop.webp',
      introDuration: Duration(milliseconds: 3071),
    ),
    'light-cycles': ProfileEffectConfig(
      id: 'light-cycles',
      name: 'Light Cycles',
      introUrl: 'https://cdn.katsklub.top/effects/light-cycles/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/light-cycles/loop.webp',
      introDuration: Duration(milliseconds: 3071),
    ),
    'infinite_swirl': ProfileEffectConfig(
      id: 'infinite_swirl',
      name: 'Infinite Swirl',
      introUrl: 'https://cdn.katsklub.top/effects/infinite-swirl/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/infinite-swirl/loop.webp',
      introDuration: Duration(milliseconds: 3984),
    ),
    'infinite-swirl': ProfileEffectConfig(
      id: 'infinite-swirl',
      name: 'Infinite Swirl',
      introUrl: 'https://cdn.katsklub.top/effects/infinite-swirl/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/infinite-swirl/loop.webp',
      introDuration: Duration(milliseconds: 3984),
    ),
    'encom_grid': ProfileEffectConfig(
      id: 'encom_grid',
      name: 'Encom Grid',
      introUrl: 'https://cdn.katsklub.top/effects/encom-grid/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/encom-grid/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'encom-grid': ProfileEffectConfig(
      id: 'encom-grid',
      name: 'Encom Grid',
      introUrl: 'https://cdn.katsklub.top/effects/encom-grid/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/encom-grid/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'cosmic_twilight_beryl': ProfileEffectConfig(
      id: 'cosmic_twilight_beryl',
      name: 'Cosmic Twilight (Beryl)',
      introUrl: 'https://cdn.katsklub.top/effects/cosmic-twilight-beryl/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/cosmic-twilight-beryl/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'cosmic-twilight-beryl': ProfileEffectConfig(
      id: 'cosmic-twilight-beryl',
      name: 'Cosmic Twilight (Beryl)',
      introUrl: 'https://cdn.katsklub.top/effects/cosmic-twilight-beryl/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/cosmic-twilight-beryl/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'cosmic_twilight_dusk': ProfileEffectConfig(
      id: 'cosmic_twilight_dusk',
      name: 'Cosmic Twilight (Dusk)',
      introUrl: 'https://cdn.katsklub.top/effects/cosmic-twilight-dusk/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/cosmic-twilight-dusk/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'cosmic-twilight-dusk': ProfileEffectConfig(
      id: 'cosmic-twilight-dusk',
      name: 'Cosmic Twilight (Dusk)',
      introUrl: 'https://cdn.katsklub.top/effects/cosmic-twilight-dusk/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/cosmic-twilight-dusk/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'star_swirl_blue': ProfileEffectConfig(
      id: 'star_swirl_blue',
      name: 'Star Swirl (Blue)',
      introUrl: 'https://cdn.katsklub.top/effects/star-swirl-blue/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/star-swirl-blue/loop.webp',
      introDuration: Duration(milliseconds: 3984),
    ),
    'star-swirl-blue': ProfileEffectConfig(
      id: 'star-swirl-blue',
      name: 'Star Swirl (Blue)',
      introUrl: 'https://cdn.katsklub.top/effects/star-swirl-blue/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/star-swirl-blue/loop.webp',
      introDuration: Duration(milliseconds: 3984),
    ),
    'cosmic_twilight_amethyst': ProfileEffectConfig(
      id: 'cosmic_twilight_amethyst',
      name: 'Cosmic Twilight (Amethyst)',
      introUrl: 'https://cdn.katsklub.top/effects/cosmic-twilight-amethyst/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/cosmic-twilight-amethyst/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'cosmic-twilight-amethyst': ProfileEffectConfig(
      id: 'cosmic-twilight-amethyst',
      name: 'Cosmic Twilight (Amethyst)',
      introUrl: 'https://cdn.katsklub.top/effects/cosmic-twilight-amethyst/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/cosmic-twilight-amethyst/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'cosmic_twilight_fuschia': ProfileEffectConfig(
      id: 'cosmic_twilight_fuschia',
      name: 'Cosmic Twilight (Fuschia)',
      introUrl: 'https://cdn.katsklub.top/effects/cosmic-twilight-fuschia/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/cosmic-twilight-fuschia/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'cosmic-twilight-fuschia': ProfileEffectConfig(
      id: 'cosmic-twilight-fuschia',
      name: 'Cosmic Twilight (Fuschia)',
      introUrl: 'https://cdn.katsklub.top/effects/cosmic-twilight-fuschia/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/cosmic-twilight-fuschia/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'cosmic_storm': ProfileEffectConfig(
      id: 'cosmic_storm',
      name: 'Cosmic Storm',
      introUrl: 'https://cdn.katsklub.top/effects/cosmic-storm/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/cosmic-storm/loop.webp',
      introDuration: Duration(milliseconds: 3486),
    ),
    'cosmic-storm': ProfileEffectConfig(
      id: 'cosmic-storm',
      name: 'Cosmic Storm',
      introUrl: 'https://cdn.katsklub.top/effects/cosmic-storm/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/cosmic-storm/loop.webp',
      introDuration: Duration(milliseconds: 3486),
    ),
    'star_swirl_amethyst': ProfileEffectConfig(
      id: 'star_swirl_amethyst',
      name: 'Star Swirl (Amethyst)',
      introUrl: 'https://cdn.katsklub.top/effects/star-swirl-amethyst/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/star-swirl-amethyst/loop.webp',
      introDuration: Duration(milliseconds: 3984),
    ),
    'star-swirl-amethyst': ProfileEffectConfig(
      id: 'star-swirl-amethyst',
      name: 'Star Swirl (Amethyst)',
      introUrl: 'https://cdn.katsklub.top/effects/star-swirl-amethyst/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/star-swirl-amethyst/loop.webp',
      introDuration: Duration(milliseconds: 3984),
    ),
    'woodsprites': ProfileEffectConfig(
      id: 'woodsprites',
      name: 'Woodsprites',
      introUrl: 'https://cdn.katsklub.top/effects/woodsprites/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/woodsprites/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'planet_rings': ProfileEffectConfig(
      id: 'planet_rings',
      name: 'Planet Rings',
      introUrl: 'https://cdn.katsklub.top/effects/planet-rings/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/planet-rings/loop.webp',
      introDuration: Duration(milliseconds: 3984),
    ),
    'planet-rings': ProfileEffectConfig(
      id: 'planet-rings',
      name: 'Planet Rings',
      introUrl: 'https://cdn.katsklub.top/effects/planet-rings/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/planet-rings/loop.webp',
      introDuration: Duration(milliseconds: 3984),
    ),
    'hallelujah_mountains': ProfileEffectConfig(
      id: 'hallelujah_mountains',
      name: 'Hallelujah Mountains',
      introUrl: 'https://cdn.katsklub.top/effects/hallelujah-mountains/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/hallelujah-mountains/loop.webp',
      introDuration: Duration(milliseconds: 3735),
    ),
    'hallelujah-mountains': ProfileEffectConfig(
      id: 'hallelujah-mountains',
      name: 'Hallelujah Mountains',
      introUrl: 'https://cdn.katsklub.top/effects/hallelujah-mountains/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/hallelujah-mountains/loop.webp',
      introDuration: Duration(milliseconds: 3735),
    ),
    'star_swirl_dusk': ProfileEffectConfig(
      id: 'star_swirl_dusk',
      name: 'Star Swirl (Dusk)',
      introUrl: 'https://cdn.katsklub.top/effects/star-swirl-dusk/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/star-swirl-dusk/loop.webp',
      introDuration: Duration(milliseconds: 3984),
    ),
    'star-swirl-dusk': ProfileEffectConfig(
      id: 'star-swirl-dusk',
      name: 'Star Swirl (Dusk)',
      introUrl: 'https://cdn.katsklub.top/effects/star-swirl-dusk/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/star-swirl-dusk/loop.webp',
      introDuration: Duration(milliseconds: 3984),
    ),
    'star_swirl_rose': ProfileEffectConfig(
      id: 'star_swirl_rose',
      name: 'Star Swirl (Rose)',
      introUrl: 'https://cdn.katsklub.top/effects/star-swirl-rose/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/star-swirl-rose/loop.webp',
      introDuration: Duration(milliseconds: 3984),
    ),
    'star-swirl-rose': ProfileEffectConfig(
      id: 'star-swirl-rose',
      name: 'Star Swirl (Rose)',
      introUrl: 'https://cdn.katsklub.top/effects/star-swirl-rose/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/star-swirl-rose/loop.webp',
      introDuration: Duration(milliseconds: 3984),
    ),
    'nightwraith': ProfileEffectConfig(
      id: 'nightwraith',
      name: 'Nightwraith',
      introUrl: 'https://cdn.katsklub.top/effects/nightwraith/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/nightwraith/loop.webp',
      introDuration: Duration(milliseconds: 4981),
    ),
    'the_hermit': ProfileEffectConfig(
      id: 'the_hermit',
      name: 'The Hermit',
      introUrl: 'https://cdn.katsklub.top/effects/the-hermit/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/the-hermit/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'the-hermit': ProfileEffectConfig(
      id: 'the-hermit',
      name: 'The Hermit',
      introUrl: 'https://cdn.katsklub.top/effects/the-hermit/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/the-hermit/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'cancer': ProfileEffectConfig(
      id: 'cancer',
      name: 'Cancer',
      introUrl: 'https://cdn.katsklub.top/effects/cancer/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/cancer/loop.webp',
      introDuration: Duration(milliseconds: 4152),
    ),
    'scorpio': ProfileEffectConfig(
      id: 'scorpio',
      name: 'Scorpio',
      introUrl: 'https://cdn.katsklub.top/effects/scorpio/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/scorpio/loop.webp',
      introDuration: Duration(milliseconds: 3985),
    ),
    'dream_waves_blue': ProfileEffectConfig(
      id: 'dream_waves_blue',
      name: 'Dream Waves (Blue)',
      introUrl: 'https://cdn.katsklub.top/effects/dream-waves-blue/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/dream-waves-blue/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'dream-waves-blue': ProfileEffectConfig(
      id: 'dream-waves-blue',
      name: 'Dream Waves (Blue)',
      introUrl: 'https://cdn.katsklub.top/effects/dream-waves-blue/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/dream-waves-blue/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'dream_waves_green': ProfileEffectConfig(
      id: 'dream_waves_green',
      name: 'Dream Waves (Green)',
      introUrl: 'https://cdn.katsklub.top/effects/dream-waves-green/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/dream-waves-green/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'dream-waves-green': ProfileEffectConfig(
      id: 'dream-waves-green',
      name: 'Dream Waves (Green)',
      introUrl: 'https://cdn.katsklub.top/effects/dream-waves-green/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/dream-waves-green/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'aquarius': ProfileEffectConfig(
      id: 'aquarius',
      name: 'Aquarius',
      introUrl: 'https://cdn.katsklub.top/effects/aquarius/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/aquarius/loop.webp',
      introDuration: Duration(milliseconds: 4067),
    ),
    'gemini': ProfileEffectConfig(
      id: 'gemini',
      name: 'Gemini',
      introUrl: 'https://cdn.katsklub.top/effects/gemini/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/gemini/loop.webp',
      introDuration: Duration(milliseconds: 4150),
    ),
    'the_magician': ProfileEffectConfig(
      id: 'the_magician',
      name: 'The Magician',
      introUrl: 'https://cdn.katsklub.top/effects/the-magician/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/the-magician/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'the-magician': ProfileEffectConfig(
      id: 'the-magician',
      name: 'The Magician',
      introUrl: 'https://cdn.katsklub.top/effects/the-magician/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/the-magician/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'the_tower': ProfileEffectConfig(
      id: 'the_tower',
      name: 'The Tower',
      introUrl: 'https://cdn.katsklub.top/effects/the-tower/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/the-tower/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'the-tower': ProfileEffectConfig(
      id: 'the-tower',
      name: 'The Tower',
      introUrl: 'https://cdn.katsklub.top/effects/the-tower/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/the-tower/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'libra': ProfileEffectConfig(
      id: 'libra',
      name: 'Libra',
      introUrl: 'https://cdn.katsklub.top/effects/libra/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/libra/loop.webp',
      introDuration: Duration(milliseconds: 3984),
    ),
    'virgo': ProfileEffectConfig(
      id: 'virgo',
      name: 'Virgo',
      introUrl: 'https://cdn.katsklub.top/effects/virgo/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/virgo/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'star_drift': ProfileEffectConfig(
      id: 'star_drift',
      name: 'Star Drift',
      introUrl: 'https://cdn.katsklub.top/effects/star-drift/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/star-drift/loop.webp',
      introDuration: Duration(milliseconds: 4068),
    ),
    'star-drift': ProfileEffectConfig(
      id: 'star-drift',
      name: 'Star Drift',
      introUrl: 'https://cdn.katsklub.top/effects/star-drift/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/star-drift/loop.webp',
      introDuration: Duration(milliseconds: 4068),
    ),
    'counting_sheep': ProfileEffectConfig(
      id: 'counting_sheep',
      name: 'Counting Sheep',
      introUrl: 'https://cdn.katsklub.top/effects/counting-sheep/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/counting-sheep/loop.webp',
      introDuration: Duration(milliseconds: 3984),
    ),
    'counting-sheep': ProfileEffectConfig(
      id: 'counting-sheep',
      name: 'Counting Sheep',
      introUrl: 'https://cdn.katsklub.top/effects/counting-sheep/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/counting-sheep/loop.webp',
      introDuration: Duration(milliseconds: 3984),
    ),
    'pisces': ProfileEffectConfig(
      id: 'pisces',
      name: 'Pisces',
      introUrl: 'https://cdn.katsklub.top/effects/pisces/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/pisces/loop.webp',
      introDuration: Duration(milliseconds: 3984),
    ),
    'dream_waves_white': ProfileEffectConfig(
      id: 'dream_waves_white',
      name: 'Dream Waves (White)',
      introUrl: 'https://cdn.katsklub.top/effects/dream-waves-white/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/dream-waves-white/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'dream-waves-white': ProfileEffectConfig(
      id: 'dream-waves-white',
      name: 'Dream Waves (White)',
      introUrl: 'https://cdn.katsklub.top/effects/dream-waves-white/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/dream-waves-white/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'taurus': ProfileEffectConfig(
      id: 'taurus',
      name: 'Taurus',
      introUrl: 'https://cdn.katsklub.top/effects/taurus/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/taurus/loop.webp',
      introDuration: Duration(milliseconds: 3984),
    ),
    'dream_waves_pink': ProfileEffectConfig(
      id: 'dream_waves_pink',
      name: 'Dream Waves (Pink)',
      introUrl: 'https://cdn.katsklub.top/effects/dream-waves-pink/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/dream-waves-pink/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'dream-waves-pink': ProfileEffectConfig(
      id: 'dream-waves-pink',
      name: 'Dream Waves (Pink)',
      introUrl: 'https://cdn.katsklub.top/effects/dream-waves-pink/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/dream-waves-pink/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'capricorn': ProfileEffectConfig(
      id: 'capricorn',
      name: 'Capricorn',
      introUrl: 'https://cdn.katsklub.top/effects/capricorn/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/capricorn/loop.webp',
      introDuration: Duration(milliseconds: 4316),
    ),
    'sagittarius': ProfileEffectConfig(
      id: 'sagittarius',
      name: 'Sagittarius',
      introUrl: 'https://cdn.katsklub.top/effects/sagittarius/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/sagittarius/loop.webp',
      introDuration: Duration(milliseconds: 3984),
    ),
    'aries': ProfileEffectConfig(
      id: 'aries',
      name: 'Aries',
      introUrl: 'https://cdn.katsklub.top/effects/aries/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/aries/loop.webp',
      introDuration: Duration(milliseconds: 3985),
    ),
    'dream_waves_purple': ProfileEffectConfig(
      id: 'dream_waves_purple',
      name: 'Dream Waves (Purple)',
      introUrl: 'https://cdn.katsklub.top/effects/dream-waves-purple/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/dream-waves-purple/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'dream-waves-purple': ProfileEffectConfig(
      id: 'dream-waves-purple',
      name: 'Dream Waves (Purple)',
      introUrl: 'https://cdn.katsklub.top/effects/dream-waves-purple/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/dream-waves-purple/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'leo': ProfileEffectConfig(
      id: 'leo',
      name: 'Leo',
      introUrl: 'https://cdn.katsklub.top/effects/leo/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/leo/loop.webp',
      introDuration: Duration(milliseconds: 3984),
    ),
    'nevermore_midnight': ProfileEffectConfig(
      id: 'nevermore_midnight',
      name: 'Nevermore (Midnight)',
      introUrl: 'https://cdn.katsklub.top/effects/nevermore-midnight/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/nevermore-midnight/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'nevermore-midnight': ProfileEffectConfig(
      id: 'nevermore-midnight',
      name: 'Nevermore (Midnight)',
      introUrl: 'https://cdn.katsklub.top/effects/nevermore-midnight/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/nevermore-midnight/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'gothic_arches': ProfileEffectConfig(
      id: 'gothic_arches',
      name: 'Gothic Arches',
      introUrl: 'https://cdn.katsklub.top/effects/gothic-arches/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/gothic-arches/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'gothic-arches': ProfileEffectConfig(
      id: 'gothic-arches',
      name: 'Gothic Arches',
      introUrl: 'https://cdn.katsklub.top/effects/gothic-arches/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/gothic-arches/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'dark_roses_black': ProfileEffectConfig(
      id: 'dark_roses_black',
      name: 'Dark Roses (Black)',
      introUrl: 'https://cdn.katsklub.top/effects/dark-roses-black/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/dark-roses-black/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'dark-roses-black': ProfileEffectConfig(
      id: 'dark-roses-black',
      name: 'Dark Roses (Black)',
      introUrl: 'https://cdn.katsklub.top/effects/dark-roses-black/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/dark-roses-black/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'dark_roses_white': ProfileEffectConfig(
      id: 'dark_roses_white',
      name: 'Dark Roses (White)',
      introUrl: 'https://cdn.katsklub.top/effects/dark-roses-white/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/dark-roses-white/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'dark-roses-white': ProfileEffectConfig(
      id: 'dark-roses-white',
      name: 'Dark Roses (White)',
      introUrl: 'https://cdn.katsklub.top/effects/dark-roses-white/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/dark-roses-white/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'nevermore_crimson': ProfileEffectConfig(
      id: 'nevermore_crimson',
      name: 'Nevermore (Crimson)',
      introUrl: 'https://cdn.katsklub.top/effects/nevermore-crimson/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/nevermore-crimson/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'nevermore-crimson': ProfileEffectConfig(
      id: 'nevermore-crimson',
      name: 'Nevermore (Crimson)',
      introUrl: 'https://cdn.katsklub.top/effects/nevermore-crimson/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/nevermore-crimson/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'dark_roses_nightshade': ProfileEffectConfig(
      id: 'dark_roses_nightshade',
      name: 'Dark Roses (Nightshade)',
      introUrl: 'https://cdn.katsklub.top/effects/dark-roses-nightshade/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/dark-roses-nightshade/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'dark-roses-nightshade': ProfileEffectConfig(
      id: 'dark-roses-nightshade',
      name: 'Dark Roses (Nightshade)',
      introUrl: 'https://cdn.katsklub.top/effects/dark-roses-nightshade/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/dark-roses-nightshade/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'dark_roses_blue': ProfileEffectConfig(
      id: 'dark_roses_blue',
      name: 'Dark Roses (Blue)',
      introUrl: 'https://cdn.katsklub.top/effects/dark-roses-blue/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/dark-roses-blue/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'dark-roses-blue': ProfileEffectConfig(
      id: 'dark-roses-blue',
      name: 'Dark Roses (Blue)',
      introUrl: 'https://cdn.katsklub.top/effects/dark-roses-blue/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/dark-roses-blue/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'nevermore_white': ProfileEffectConfig(
      id: 'nevermore_white',
      name: 'Nevermore (White)',
      introUrl: 'https://cdn.katsklub.top/effects/nevermore-white/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/nevermore-white/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'nevermore-white': ProfileEffectConfig(
      id: 'nevermore-white',
      name: 'Nevermore (White)',
      introUrl: 'https://cdn.katsklub.top/effects/nevermore-white/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/nevermore-white/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'crimson_stallion': ProfileEffectConfig(
      id: 'crimson_stallion',
      name: 'Crimson Stallion',
      introUrl: 'https://cdn.katsklub.top/effects/crimson-stallion/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/crimson-stallion/loop.webp',
      introDuration: Duration(milliseconds: 3735),
    ),
    'crimson-stallion': ProfileEffectConfig(
      id: 'crimson-stallion',
      name: 'Crimson Stallion',
      introUrl: 'https://cdn.katsklub.top/effects/crimson-stallion/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/crimson-stallion/loop.webp',
      introDuration: Duration(milliseconds: 3735),
    ),
    'lone_wolf': ProfileEffectConfig(
      id: 'lone_wolf',
      name: 'Lone Wolf',
      introUrl: 'https://cdn.katsklub.top/effects/lone-wolf/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/lone-wolf/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'lone-wolf': ProfileEffectConfig(
      id: 'lone-wolf',
      name: 'Lone Wolf',
      introUrl: 'https://cdn.katsklub.top/effects/lone-wolf/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/lone-wolf/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'match_made': ProfileEffectConfig(
      id: 'match_made',
      name: 'Match Made',
      introUrl: 'https://cdn.katsklub.top/effects/match-made/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/match-made/loop.webp',
      introDuration: Duration(milliseconds: 3486),
    ),
    'match-made': ProfileEffectConfig(
      id: 'match-made',
      name: 'Match Made',
      introUrl: 'https://cdn.katsklub.top/effects/match-made/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/match-made/loop.webp',
      introDuration: Duration(milliseconds: 3486),
    ),
    'flying_solo': ProfileEffectConfig(
      id: 'flying_solo',
      name: 'Flying Solo',
      introUrl: 'https://cdn.katsklub.top/effects/flying-solo/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/flying-solo/loop.webp',
      introDuration: Duration(milliseconds: 3486),
    ),
    'flying-solo': ProfileEffectConfig(
      id: 'flying-solo',
      name: 'Flying Solo',
      introUrl: 'https://cdn.katsklub.top/effects/flying-solo/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/flying-solo/loop.webp',
      introDuration: Duration(milliseconds: 3486),
    ),
    'lil_stinker': ProfileEffectConfig(
      id: 'lil_stinker',
      name: 'Lil Stinker',
      introUrl: 'https://cdn.katsklub.top/effects/lil-stinker/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/lil-stinker/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'lil-stinker': ProfileEffectConfig(
      id: 'lil-stinker',
      name: 'Lil Stinker',
      introUrl: 'https://cdn.katsklub.top/effects/lil-stinker/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/lil-stinker/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'hunny_bunnies': ProfileEffectConfig(
      id: 'hunny_bunnies',
      name: 'Hunny Bunnies',
      introUrl: 'https://cdn.katsklub.top/effects/hunny-bunnies/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/hunny-bunnies/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'hunny-bunnies': ProfileEffectConfig(
      id: 'hunny-bunnies',
      name: 'Hunny Bunnies',
      introUrl: 'https://cdn.katsklub.top/effects/hunny-bunnies/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/hunny-bunnies/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'cutesy': ProfileEffectConfig(
      id: 'cutesy',
      name: 'Cutesy',
      introUrl: 'https://cdn.katsklub.top/effects/cutesy/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/cutesy/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'first_breath': ProfileEffectConfig(
      id: 'first_breath',
      name: 'First Breath',
      introUrl: 'https://cdn.katsklub.top/effects/first-breath/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/first-breath/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'first-breath': ProfileEffectConfig(
      id: 'first-breath',
      name: 'First Breath',
      introUrl: 'https://cdn.katsklub.top/effects/first-breath/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/first-breath/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'midnight_mantas': ProfileEffectConfig(
      id: 'midnight_mantas',
      name: 'Midnight Mantas',
      introUrl: 'https://cdn.katsklub.top/effects/midnight-mantas/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/midnight-mantas/loop.webp',
      introDuration: Duration(milliseconds: 2520),
    ),
    'midnight-mantas': ProfileEffectConfig(
      id: 'midnight-mantas',
      name: 'Midnight Mantas',
      introUrl: 'https://cdn.katsklub.top/effects/midnight-mantas/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/midnight-mantas/loop.webp',
      introDuration: Duration(milliseconds: 2520),
    ),
    'spray_doodles_no_artist': ProfileEffectConfig(
      id: 'spray_doodles_no_artist',
      name: 'Spray Doodles (No Artist)',
      introUrl: 'https://cdn.katsklub.top/effects/spray-doodles-no-artist/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/spray-doodles-no-artist/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'spray-doodles-no-artist': ProfileEffectConfig(
      id: 'spray-doodles-no-artist',
      name: 'Spray Doodles (No Artist)',
      introUrl: 'https://cdn.katsklub.top/effects/spray-doodles-no-artist/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/spray-doodles-no-artist/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'soaring_mando': ProfileEffectConfig(
      id: 'soaring_mando',
      name: 'Soaring Mando',
      introUrl: 'https://cdn.katsklub.top/effects/soaring-mando/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/soaring-mando/loop.webp',
      introDuration: Duration(milliseconds: 4483),
    ),
    'soaring-mando': ProfileEffectConfig(
      id: 'soaring-mando',
      name: 'Soaring Mando',
      introUrl: 'https://cdn.katsklub.top/effects/soaring-mando/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/soaring-mando/loop.webp',
      introDuration: Duration(milliseconds: 4483),
    ),
    'hover_pram': ProfileEffectConfig(
      id: 'hover_pram',
      name: 'Hover Pram',
      introUrl: 'https://cdn.katsklub.top/effects/hover-pram/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/hover-pram/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'hover-pram': ProfileEffectConfig(
      id: 'hover-pram',
      name: 'Hover Pram',
      introUrl: 'https://cdn.katsklub.top/effects/hover-pram/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/hover-pram/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'mando_and_grogu': ProfileEffectConfig(
      id: 'mando_and_grogu',
      name: 'Mando and Grogu',
      introUrl: 'https://cdn.katsklub.top/effects/mando-and-grogu/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/mando-and-grogu/loop.webp',
      introDuration: Duration(milliseconds: 4982),
    ),
    'mando-and-grogu': ProfileEffectConfig(
      id: 'mando-and-grogu',
      name: 'Mando and Grogu',
      introUrl: 'https://cdn.katsklub.top/effects/mando-and-grogu/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/mando-and-grogu/loop.webp',
      introDuration: Duration(milliseconds: 4982),
    ),
    'starlight_wand': ProfileEffectConfig(
      id: 'starlight_wand',
      name: 'Starlight Wand',
      introUrl: 'https://cdn.katsklub.top/effects/starlight-wand/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/starlight-wand/loop.webp',
      introDuration: Duration(milliseconds: 3984),
    ),
    'starlight-wand': ProfileEffectConfig(
      id: 'starlight-wand',
      name: 'Starlight Wand',
      introUrl: 'https://cdn.katsklub.top/effects/starlight-wand/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/starlight-wand/loop.webp',
      introDuration: Duration(milliseconds: 3984),
    ),
    'cosmic_guardian': ProfileEffectConfig(
      id: 'cosmic_guardian',
      name: 'Cosmic Guardian',
      introUrl: 'https://cdn.katsklub.top/effects/cosmic-guardian/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/cosmic-guardian/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'cosmic-guardian': ProfileEffectConfig(
      id: 'cosmic-guardian',
      name: 'Cosmic Guardian',
      introUrl: 'https://cdn.katsklub.top/effects/cosmic-guardian/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/cosmic-guardian/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'heart_beam': ProfileEffectConfig(
      id: 'heart_beam',
      name: 'Heart Beam',
      introUrl: 'https://cdn.katsklub.top/effects/heart-beam/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/heart-beam/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'heart-beam': ProfileEffectConfig(
      id: 'heart-beam',
      name: 'Heart Beam',
      introUrl: 'https://cdn.katsklub.top/effects/heart-beam/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/heart-beam/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'bananabelle': ProfileEffectConfig(
      id: 'bananabelle',
      name: 'Bananabelle',
      introUrl: 'https://cdn.katsklub.top/effects/bananabelle/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/bananabelle/loop.webp',
      introDuration: Duration(milliseconds: 6059),
    ),
    'cherry_surprise': ProfileEffectConfig(
      id: 'cherry_surprise',
      name: 'Cherry Surprise',
      introUrl: 'https://cdn.katsklub.top/effects/cherry-surprise/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/cherry-surprise/loop.webp',
      introDuration: Duration(milliseconds: 3237),
    ),
    'cherry-surprise': ProfileEffectConfig(
      id: 'cherry-surprise',
      name: 'Cherry Surprise',
      introUrl: 'https://cdn.katsklub.top/effects/cherry-surprise/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/cherry-surprise/loop.webp',
      introDuration: Duration(milliseconds: 3237),
    ),
    'berry_cute': ProfileEffectConfig(
      id: 'berry_cute',
      name: 'Berry Cute',
      introUrl: 'https://cdn.katsklub.top/effects/berry-cute/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/berry-cute/loop.webp',
      introDuration: Duration(milliseconds: 3320),
    ),
    'berry-cute': ProfileEffectConfig(
      id: 'berry-cute',
      name: 'Berry Cute',
      introUrl: 'https://cdn.katsklub.top/effects/berry-cute/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/berry-cute/loop.webp',
      introDuration: Duration(milliseconds: 3320),
    ),
    'star_struck': ProfileEffectConfig(
      id: 'star_struck',
      name: 'Star Struck',
      introUrl: 'https://cdn.katsklub.top/effects/star-struck/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/star-struck/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'star-struck': ProfileEffectConfig(
      id: 'star-struck',
      name: 'Star Struck',
      introUrl: 'https://cdn.katsklub.top/effects/star-struck/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/star-struck/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'buggy_branches': ProfileEffectConfig(
      id: 'buggy_branches',
      name: 'Buggy Branches',
      introUrl: 'https://cdn.katsklub.top/effects/buggy-branches/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/buggy-branches/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'buggy-branches': ProfileEffectConfig(
      id: 'buggy-branches',
      name: 'Buggy Branches',
      introUrl: 'https://cdn.katsklub.top/effects/buggy-branches/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/buggy-branches/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'ladybug_luau': ProfileEffectConfig(
      id: 'ladybug_luau',
      name: 'Ladybug Luau',
      introUrl: 'https://cdn.katsklub.top/effects/ladybug-luau/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/ladybug-luau/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'ladybug-luau': ProfileEffectConfig(
      id: 'ladybug-luau',
      name: 'Ladybug Luau',
      introUrl: 'https://cdn.katsklub.top/effects/ladybug-luau/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/ladybug-luau/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'hello_kitty': ProfileEffectConfig(
      id: 'hello_kitty',
      name: 'Hello Kitty',
      introUrl: 'https://cdn.katsklub.top/effects/hello-kitty/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/hello-kitty/loop.webp',
      introDuration: Duration(milliseconds: 4897),
    ),
    'hello-kitty': ProfileEffectConfig(
      id: 'hello-kitty',
      name: 'Hello Kitty',
      introUrl: 'https://cdn.katsklub.top/effects/hello-kitty/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/hello-kitty/loop.webp',
      introDuration: Duration(milliseconds: 4897),
    ),
    'pompompurin': ProfileEffectConfig(
      id: 'pompompurin',
      name: 'Pompompurin',
      introUrl: 'https://cdn.katsklub.top/effects/pompompurin/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/pompompurin/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'cinnamoroll': ProfileEffectConfig(
      id: 'cinnamoroll',
      name: 'Cinnamoroll',
      introUrl: 'https://cdn.katsklub.top/effects/cinnamoroll/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/cinnamoroll/loop.webp',
      introDuration: Duration(milliseconds: 4567),
    ),
    'kuromi_x_my_melody': ProfileEffectConfig(
      id: 'kuromi_x_my_melody',
      name: 'Kuromi x My Melody',
      introUrl: 'https://cdn.katsklub.top/effects/kuromi-x-my-melody/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/kuromi-x-my-melody/loop.webp',
      introDuration: Duration(milliseconds: 4981),
    ),
    'kuromi-x-my-melody': ProfileEffectConfig(
      id: 'kuromi-x-my-melody',
      name: 'Kuromi x My Melody',
      introUrl: 'https://cdn.katsklub.top/effects/kuromi-x-my-melody/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/kuromi-x-my-melody/loop.webp',
      introDuration: Duration(milliseconds: 4981),
    ),
    'playground_pals': ProfileEffectConfig(
      id: 'playground_pals',
      name: 'Playground Pals',
      introUrl: 'https://cdn.katsklub.top/effects/playground-pals/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/playground-pals/loop.webp',
      introDuration: Duration(milliseconds: 4981),
    ),
    'playground-pals': ProfileEffectConfig(
      id: 'playground-pals',
      name: 'Playground Pals',
      introUrl: 'https://cdn.katsklub.top/effects/playground-pals/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/playground-pals/loop.webp',
      introDuration: Duration(milliseconds: 4981),
    ),
    'littletwinstars': ProfileEffectConfig(
      id: 'littletwinstars',
      name: 'LittleTwinStars',
      introUrl: 'https://cdn.katsklub.top/effects/littletwinstars/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/littletwinstars/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'venom': ProfileEffectConfig(
      id: 'venom',
      name: 'Venom',
      introUrl: 'https://cdn.katsklub.top/effects/venom/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/venom/loop.webp',
      introDuration: Duration(milliseconds: 3528),
    ),
    'spider_man': ProfileEffectConfig(
      id: 'spider_man',
      name: 'Spider-Man',
      introUrl: 'https://cdn.katsklub.top/effects/spider-man/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/spider-man/loop.webp',
      introDuration: Duration(milliseconds: 3737),
    ),
    'spider-man': ProfileEffectConfig(
      id: 'spider-man',
      name: 'Spider-Man',
      introUrl: 'https://cdn.katsklub.top/effects/spider-man/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/spider-man/loop.webp',
      introDuration: Duration(milliseconds: 3737),
    ),
    'enchanted_cosmos': ProfileEffectConfig(
      id: 'enchanted_cosmos',
      name: 'Enchanted Cosmos',
      introUrl: 'https://cdn.katsklub.top/effects/enchanted-cosmos/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/enchanted-cosmos/loop.webp',
      introDuration: Duration(milliseconds: 4982),
    ),
    'enchanted-cosmos': ProfileEffectConfig(
      id: 'enchanted-cosmos',
      name: 'Enchanted Cosmos',
      introUrl: 'https://cdn.katsklub.top/effects/enchanted-cosmos/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/enchanted-cosmos/loop.webp',
      introDuration: Duration(milliseconds: 4982),
    ),
    'dream_hop_portal': ProfileEffectConfig(
      id: 'dream_hop_portal',
      name: 'Dream Hop Portal',
      introUrl: 'https://cdn.katsklub.top/effects/dream-hop-portal/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/dream-hop-portal/loop.webp',
      introDuration: Duration(milliseconds: 5063),
    ),
    'dream-hop-portal': ProfileEffectConfig(
      id: 'dream-hop-portal',
      name: 'Dream Hop Portal',
      introUrl: 'https://cdn.katsklub.top/effects/dream-hop-portal/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/dream-hop-portal/loop.webp',
      introDuration: Duration(milliseconds: 5063),
    ),
    'cloud_kingdom': ProfileEffectConfig(
      id: 'cloud_kingdom',
      name: 'Cloud Kingdom',
      introUrl: 'https://cdn.katsklub.top/effects/cloud-kingdom/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/cloud-kingdom/loop.webp',
      introDuration: Duration(milliseconds: 4981),
    ),
    'cloud-kingdom': ProfileEffectConfig(
      id: 'cloud-kingdom',
      name: 'Cloud Kingdom',
      introUrl: 'https://cdn.katsklub.top/effects/cloud-kingdom/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/cloud-kingdom/loop.webp',
      introDuration: Duration(milliseconds: 4981),
    ),
    'lucky_era': ProfileEffectConfig(
      id: 'lucky_era',
      name: 'Lucky Era',
      introUrl: 'https://cdn.katsklub.top/effects/lucky-era/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/lucky-era/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'lucky-era': ProfileEffectConfig(
      id: 'lucky-era',
      name: 'Lucky Era',
      introUrl: 'https://cdn.katsklub.top/effects/lucky-era/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/lucky-era/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'neon_glow_kunzite': ProfileEffectConfig(
      id: 'neon_glow_kunzite',
      name: 'Neon Glow (Kunzite)',
      introUrl: 'https://cdn.katsklub.top/effects/neon-glow-kunzite/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/neon-glow-kunzite/loop.webp',
      introDuration: Duration(milliseconds: 1992),
    ),
    'neon-glow-kunzite': ProfileEffectConfig(
      id: 'neon-glow-kunzite',
      name: 'Neon Glow (Kunzite)',
      introUrl: 'https://cdn.katsklub.top/effects/neon-glow-kunzite/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/neon-glow-kunzite/loop.webp',
      introDuration: Duration(milliseconds: 1992),
    ),
    'drifting_glow_twilight': ProfileEffectConfig(
      id: 'drifting_glow_twilight',
      name: 'Drifting Glow (Twilight)',
      introUrl: 'https://cdn.katsklub.top/effects/drifting-glow-twilight/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/drifting-glow-twilight/loop.webp',
      introDuration: Duration(milliseconds: 1992),
    ),
    'drifting-glow-twilight': ProfileEffectConfig(
      id: 'drifting-glow-twilight',
      name: 'Drifting Glow (Twilight)',
      introUrl: 'https://cdn.katsklub.top/effects/drifting-glow-twilight/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/drifting-glow-twilight/loop.webp',
      introDuration: Duration(milliseconds: 1992),
    ),
    'electric_aura_thistle': ProfileEffectConfig(
      id: 'electric_aura_thistle',
      name: 'Electric Aura (Thistle)',
      introUrl: 'https://cdn.katsklub.top/effects/electric-aura-thistle/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/electric-aura-thistle/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'electric-aura-thistle': ProfileEffectConfig(
      id: 'electric-aura-thistle',
      name: 'Electric Aura (Thistle)',
      introUrl: 'https://cdn.katsklub.top/effects/electric-aura-thistle/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/electric-aura-thistle/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'sky_lanterns': ProfileEffectConfig(
      id: 'sky_lanterns',
      name: 'Sky Lanterns',
      introUrl: 'https://cdn.katsklub.top/effects/sky-lanterns/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/sky-lanterns/loop.webp',
      introDuration: Duration(milliseconds: 5064),
    ),
    'sky-lanterns': ProfileEffectConfig(
      id: 'sky-lanterns',
      name: 'Sky Lanterns',
      introUrl: 'https://cdn.katsklub.top/effects/sky-lanterns/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/sky-lanterns/loop.webp',
      introDuration: Duration(milliseconds: 5064),
    ),
    'kawaii_clouds': ProfileEffectConfig(
      id: 'kawaii_clouds',
      name: 'Kawaii Clouds',
      introUrl: 'https://cdn.katsklub.top/effects/kawaii-clouds/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/kawaii-clouds/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'kawaii-clouds': ProfileEffectConfig(
      id: 'kawaii-clouds',
      name: 'Kawaii Clouds',
      introUrl: 'https://cdn.katsklub.top/effects/kawaii-clouds/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/kawaii-clouds/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'lofi_cat_zoomies': ProfileEffectConfig(
      id: 'lofi_cat_zoomies',
      name: 'Lofi Cat Zoomies',
      introUrl: 'https://cdn.katsklub.top/effects/lofi-cat-zoomies/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/lofi-cat-zoomies/loop.webp',
      introDuration: Duration(milliseconds: 5649),
    ),
    'lofi-cat-zoomies': ProfileEffectConfig(
      id: 'lofi-cat-zoomies',
      name: 'Lofi Cat Zoomies',
      introUrl: 'https://cdn.katsklub.top/effects/lofi-cat-zoomies/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/lofi-cat-zoomies/loop.webp',
      introDuration: Duration(milliseconds: 5649),
    ),
    'peek_a_boo': ProfileEffectConfig(
      id: 'peek_a_boo',
      name: 'Peek a Boo',
      introUrl: 'https://cdn.katsklub.top/effects/peek-a-boo/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/peek-a-boo/loop.webp',
      introDuration: Duration(milliseconds: 4402),
    ),
    'peek-a-boo': ProfileEffectConfig(
      id: 'peek-a-boo',
      name: 'Peek a Boo',
      introUrl: 'https://cdn.katsklub.top/effects/peek-a-boo/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/peek-a-boo/loop.webp',
      introDuration: Duration(milliseconds: 4402),
    ),
    'falling_with_style_base': ProfileEffectConfig(
      id: 'falling_with_style_base',
      name: 'Falling With Style (Base)',
      introUrl: 'https://cdn.katsklub.top/effects/falling-with-style-base/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/falling-with-style-base/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'falling-with-style-base': ProfileEffectConfig(
      id: 'falling-with-style-base',
      name: 'Falling With Style (Base)',
      introUrl: 'https://cdn.katsklub.top/effects/falling-with-style-base/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/falling-with-style-base/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'falling_with_style_clouds_only': ProfileEffectConfig(
      id: 'falling_with_style_clouds_only',
      name: 'Falling With Style (Clouds Only)',
      introUrl: 'https://cdn.katsklub.top/effects/falling-with-style-clouds-only/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/falling-with-style-clouds-only/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'falling-with-style-clouds-only': ProfileEffectConfig(
      id: 'falling-with-style-clouds-only',
      name: 'Falling With Style (Clouds Only)',
      introUrl: 'https://cdn.katsklub.top/effects/falling-with-style-clouds-only/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/falling-with-style-clouds-only/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'death_s_head_hawkmoth': ProfileEffectConfig(
      id: 'death_s_head_hawkmoth',
      name: 'Death\'s-Head Hawkmoth',
      introUrl: 'https://cdn.katsklub.top/effects/death-s-head-hawkmoth/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/death-s-head-hawkmoth/loop.webp',
      introDuration: Duration(milliseconds: 4731),
    ),
    'death-s-head-hawkmoth': ProfileEffectConfig(
      id: 'death-s-head-hawkmoth',
      name: 'Death\'s-Head Hawkmoth',
      introUrl: 'https://cdn.katsklub.top/effects/death-s-head-hawkmoth/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/death-s-head-hawkmoth/loop.webp',
      introDuration: Duration(milliseconds: 4731),
    ),
    'praying_mantis': ProfileEffectConfig(
      id: 'praying_mantis',
      name: 'Praying Mantis',
      introUrl: 'https://cdn.katsklub.top/effects/praying-mantis/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/praying-mantis/loop.webp',
      introDuration: Duration(milliseconds: 5148),
    ),
    'praying-mantis': ProfileEffectConfig(
      id: 'praying-mantis',
      name: 'Praying Mantis',
      introUrl: 'https://cdn.katsklub.top/effects/praying-mantis/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/praying-mantis/loop.webp',
      introDuration: Duration(milliseconds: 5148),
    ),
    'dragonfly': ProfileEffectConfig(
      id: 'dragonfly',
      name: 'Dragonfly',
      introUrl: 'https://cdn.katsklub.top/effects/dragonfly/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/dragonfly/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'lord_of_the_dead_blue': ProfileEffectConfig(
      id: 'lord_of_the_dead_blue',
      name: 'Lord of the Dead (Blue)',
      introUrl: 'https://cdn.katsklub.top/effects/lord-of-the-dead-blue/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/lord-of-the-dead-blue/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'lord-of-the-dead-blue': ProfileEffectConfig(
      id: 'lord-of-the-dead-blue',
      name: 'Lord of the Dead (Blue)',
      introUrl: 'https://cdn.katsklub.top/effects/lord-of-the-dead-blue/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/lord-of-the-dead-blue/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'hellhound': ProfileEffectConfig(
      id: 'hellhound',
      name: 'Hellhound',
      introUrl: 'https://cdn.katsklub.top/effects/hellhound/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/hellhound/loop.webp',
      introDuration: Duration(milliseconds: 3901),
    ),
    'those_left_behind': ProfileEffectConfig(
      id: 'those_left_behind',
      name: 'Those Left Behind',
      introUrl: 'https://cdn.katsklub.top/effects/those-left-behind/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/those-left-behind/loop.webp',
      introDuration: Duration(milliseconds: 4981),
    ),
    'those-left-behind': ProfileEffectConfig(
      id: 'those-left-behind',
      name: 'Those Left Behind',
      introUrl: 'https://cdn.katsklub.top/effects/those-left-behind/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/those-left-behind/loop.webp',
      introDuration: Duration(milliseconds: 4981),
    ),
    'solar_rays': ProfileEffectConfig(
      id: 'solar_rays',
      name: 'Solar Rays',
      introUrl: 'https://cdn.katsklub.top/effects/solar-rays/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/solar-rays/loop.webp',
      introDuration: Duration(milliseconds: 3984),
    ),
    'solar-rays': ProfileEffectConfig(
      id: 'solar-rays',
      name: 'Solar Rays',
      introUrl: 'https://cdn.katsklub.top/effects/solar-rays/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/solar-rays/loop.webp',
      introDuration: Duration(milliseconds: 3984),
    ),
    'suncatchers': ProfileEffectConfig(
      id: 'suncatchers',
      name: 'Suncatchers',
      introUrl: 'https://cdn.katsklub.top/effects/suncatchers/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/suncatchers/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'golden_ripples': ProfileEffectConfig(
      id: 'golden_ripples',
      name: 'Golden Ripples',
      introUrl: 'https://cdn.katsklub.top/effects/golden-ripples/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/golden-ripples/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'golden-ripples': ProfileEffectConfig(
      id: 'golden-ripples',
      name: 'Golden Ripples',
      introUrl: 'https://cdn.katsklub.top/effects/golden-ripples/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/golden-ripples/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'shiver': ProfileEffectConfig(
      id: 'shiver',
      name: 'Shiver',
      introUrl: 'https://cdn.katsklub.top/effects/shiver/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/shiver/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'always_watching': ProfileEffectConfig(
      id: 'always_watching',
      name: 'Always Watching',
      introUrl: 'https://cdn.katsklub.top/effects/always-watching/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/always-watching/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'always-watching': ProfileEffectConfig(
      id: 'always-watching',
      name: 'Always Watching',
      introUrl: 'https://cdn.katsklub.top/effects/always-watching/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/always-watching/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'let_s_play': ProfileEffectConfig(
      id: 'let_s_play',
      name: 'Let\'s Play',
      introUrl: 'https://cdn.katsklub.top/effects/let-s-play/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/let-s-play/loop.webp',
      introDuration: Duration(milliseconds: 4150),
    ),
    'let-s-play': ProfileEffectConfig(
      id: 'let-s-play',
      name: 'Let\'s Play',
      introUrl: 'https://cdn.katsklub.top/effects/let-s-play/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/let-s-play/loop.webp',
      introDuration: Duration(milliseconds: 4150),
    ),
    'trapped_souls': ProfileEffectConfig(
      id: 'trapped_souls',
      name: 'Trapped Souls',
      introUrl: 'https://cdn.katsklub.top/effects/trapped-souls/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/trapped-souls/loop.webp',
      introDuration: Duration(milliseconds: 4981),
    ),
    'trapped-souls': ProfileEffectConfig(
      id: 'trapped-souls',
      name: 'Trapped Souls',
      introUrl: 'https://cdn.katsklub.top/effects/trapped-souls/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/trapped-souls/loop.webp',
      introDuration: Duration(milliseconds: 4981),
    ),
    'cycling_lights_rgb': ProfileEffectConfig(
      id: 'cycling_lights_rgb',
      name: 'Cycling Lights (RGB)',
      introUrl: 'https://cdn.katsklub.top/effects/cycling-lights-rgb/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/cycling-lights-rgb/loop.webp',
      introDuration: Duration(milliseconds: 1992),
    ),
    'cycling-lights-rgb': ProfileEffectConfig(
      id: 'cycling-lights-rgb',
      name: 'Cycling Lights (RGB)',
      introUrl: 'https://cdn.katsklub.top/effects/cycling-lights-rgb/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/cycling-lights-rgb/loop.webp',
      introDuration: Duration(milliseconds: 1992),
    ),
    'ambient_ripples_arctic': ProfileEffectConfig(
      id: 'ambient_ripples_arctic',
      name: 'Ambient Ripples (Arctic)',
      introUrl: 'https://cdn.katsklub.top/effects/ambient-ripples-arctic/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/ambient-ripples-arctic/loop.webp',
      introDuration: Duration(milliseconds: 1992),
    ),
    'ambient-ripples-arctic': ProfileEffectConfig(
      id: 'ambient-ripples-arctic',
      name: 'Ambient Ripples (Arctic)',
      introUrl: 'https://cdn.katsklub.top/effects/ambient-ripples-arctic/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/ambient-ripples-arctic/loop.webp',
      introDuration: Duration(milliseconds: 1992),
    ),
    'ace': ProfileEffectConfig(
      id: 'ace',
      name: 'ACE',
      introUrl: 'https://cdn.katsklub.top/effects/ace/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/ace/loop.webp',
      introDuration: Duration(milliseconds: 4480),
    ),
    'mothman': ProfileEffectConfig(
      id: 'mothman',
      name: 'Mothman',
      introUrl: 'https://cdn.katsklub.top/effects/mothman/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/mothman/loop.webp',
      introDuration: Duration(milliseconds: 4982),
    ),
    'moonflowers_jackalope': ProfileEffectConfig(
      id: 'moonflowers_jackalope',
      name: 'Moonflowers (Jackalope)',
      introUrl: 'https://cdn.katsklub.top/effects/moonflowers-jackalope/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/moonflowers-jackalope/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'moonflowers-jackalope': ProfileEffectConfig(
      id: 'moonflowers-jackalope',
      name: 'Moonflowers (Jackalope)',
      introUrl: 'https://cdn.katsklub.top/effects/moonflowers-jackalope/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/moonflowers-jackalope/loop.webp',
      introDuration: Duration(milliseconds: 4980),
    ),
    'jersey_devil': ProfileEffectConfig(
      id: 'jersey_devil',
      name: 'Jersey Devil',
      introUrl: 'https://cdn.katsklub.top/effects/jersey-devil/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/jersey-devil/loop.webp',
      introDuration: Duration(milliseconds: 5063),
    ),
    'jersey-devil': ProfileEffectConfig(
      id: 'jersey-devil',
      name: 'Jersey Devil',
      introUrl: 'https://cdn.katsklub.top/effects/jersey-devil/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/jersey-devil/loop.webp',
      introDuration: Duration(milliseconds: 5063),
    ),
    'whispering_rose': ProfileEffectConfig(
      id: 'whispering_rose',
      name: 'Whispering Rose',
      introUrl: 'https://cdn.katsklub.top/effects/whispering-rose/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/whispering-rose/loop.webp',
      introDuration: Duration(milliseconds: 3984),
    ),
    'whispering-rose': ProfileEffectConfig(
      id: 'whispering-rose',
      name: 'Whispering Rose',
      introUrl: 'https://cdn.katsklub.top/effects/whispering-rose/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/whispering-rose/loop.webp',
      introDuration: Duration(milliseconds: 3984),
    ),
    'midnight_howl': ProfileEffectConfig(
      id: 'midnight_howl',
      name: 'Midnight Howl',
      introUrl: 'https://cdn.katsklub.top/effects/midnight-howl/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/midnight-howl/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'midnight-howl': ProfileEffectConfig(
      id: 'midnight-howl',
      name: 'Midnight Howl',
      introUrl: 'https://cdn.katsklub.top/effects/midnight-howl/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/midnight-howl/loop.webp',
      introDuration: Duration(milliseconds: 2988),
    ),
    'shattered_wings': ProfileEffectConfig(
      id: 'shattered_wings',
      name: 'Shattered Wings',
      introUrl: 'https://cdn.katsklub.top/effects/shattered-wings/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/shattered-wings/loop.webp',
      introDuration: Duration(milliseconds: 3984),
    ),
    'shattered-wings': ProfileEffectConfig(
      id: 'shattered-wings',
      name: 'Shattered Wings',
      introUrl: 'https://cdn.katsklub.top/effects/shattered-wings/intro.webp',
      loopUrl: 'https://cdn.katsklub.top/effects/shattered-wings/loop.webp',
      introDuration: Duration(milliseconds: 3984),
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
  Key _introKey = UniqueKey();
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
      final provider = CachedNetworkImageProvider(config.introUrl);
      // Evict any completed/stale MultiFrameImageStreamCompleter from Flutter's imageCache
      // so the intro animation ALWAYS plays fresh from frame 0 instead of showing the last frame.
      PaintingBinding.instance.imageCache.evict(provider);
      _introProvider = provider;
      _introKey = UniqueKey();
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

    // Cross-fade timing: Start fading out 350ms BEFORE the intro finishes.
    // This guarantees the intro is still in active, fluid motion while dissolving
    // into the idle loop, completely eliminating any freeze/halt on the last frame!
    const fadeDuration = Duration(milliseconds: 350);
    final totalDuration = config.introDuration;
    final fadeStartDelay = totalDuration > fadeDuration
        ? totalDuration - fadeDuration
        : Duration.zero;

    _introTimer?.cancel();
    _introTimer = Timer(fadeStartDelay, () {
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
          // Layer 1: Ambient Idle Loop
          // CRITICAL FIX: ALWAYS mounted underneath in the Stack so its WebP frames are pre-decoded
          // and warm in GPU texture memory. While the intro is playing, its opacity is 0.0.
          // When the intro begins its crossfade, the loop dissolves in from 0.0 to 1.0 with ZERO
          // cold-decode raster hitch/jank!
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
          else
            AnimatedOpacity(
              opacity: _introFadeOut ? 1.0 : 0.0,
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

          // Layer 2: Intro Animation (Starts at 100% opacity, plays from frame 0, then cross-fades out in active motion)
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
                key: _introKey,
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
