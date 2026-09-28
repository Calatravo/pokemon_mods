package org.pokemonzmods.installer;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/** Pure transformations, shared by the Android UI and host regression tests. */
public final class InstallLogic {
    public static final String[] PROFILES = {"es_218", "en_213", "fr_212p1"};
    public static final String[] LANGUAGES = {"es", "en", "fr"};
    private static final String[] HASHES = {
        "0580b2f2787c16fcbc72f6cd34155656102985f43d92a560a34232e64dea9001",
        "82ac875ca31a2b9b32f046c965e5f89dda8b479ec768d3ca2b90125943dbdfee",
        "4af6e9e7ead84e439c3ec05451dcfac46b06b70c6160e8e99f6207d18209c1b4"
    };
    public static String sha256(byte[] data) throws Exception {
        StringBuilder out = new StringBuilder();
        for (byte b : MessageDigest.getInstance("SHA-256").digest(data)) out.append(String.format("%02x", b & 255));
        return out.toString();
    }
    public static int detect(byte[] scripts) throws Exception {
        String hash = sha256(scripts);
        for (int i = 0; i < HASHES.length; i++) if (HASHES[i].equals(hash)) return i;
        return -1;
    }
    public static String preload(String old, String snippet) {
        String text = old.replace("\uFEFF", "").replaceAll(
            "(?ms)^\\s*# BEGIN POKEMON_MODS HARDCORE_NUZLOCKE\\s*$.*?^\\s*# END POKEMON_MODS HARDCORE_NUZLOCKE\\s*\\r?\\n?", "");
        // Same narrowly identified broken Zlib wrapper as the desktop installers.
        text = text.replaceAll("(?ms)^\\s*# Fix for Zlib::StreamError/Zlib:DataError by \\[ g f y \\]\\s*module Zlib\\s*class Inflate\\s*def self\\.inflate\\(string\\)\\s*MKXP\\.zinflate\\(string\\)\\s*end\\s*end\\s*class Deflate\\s*def self\\.deflate\\(string, level = 0\\)\\s*MKXP\\.zdeflate\\(string\\)\\s*end\\s*end\\s*end\\s*", "").trim();
        if (Pattern.compile("Mods.*HardcoreNuzlocke.*loader\\.rb", Pattern.DOTALL).matcher(text).find())
            throw new IllegalArgumentException("preload.rb: unrecognized existing mod loader; restore the original preload.rb first.");
        return (text.isEmpty() ? "" : text + "\n\n") + snippet.trim() + "\n";
    }
    public static String mkxp(String old) {
        String text = old.replace("\uFEFF", "");
        String active = maskComments(text);
        Pattern p = Pattern.compile("\"preloadScript\"\\s*:\\s*\\[([^\\]]*)\\]");
        Matcher m = p.matcher(active);
        if (m.find()) {
            String items = m.group(1).trim();
            if (Pattern.compile("[\"']preload\\.rb[\"']", Pattern.CASE_INSENSITIVE).matcher(items).find()) return text;
            return text.substring(0, m.start(1)) + items + (items.isEmpty() ? "" : ", ") + "\"preload.rb\"" + text.substring(m.end(1));
        }
        // Do not silently rewrite a scalar or malformed preloadScript property.
        if (Pattern.compile("\"preloadScript\"\\s*:").matcher(active).find())
            throw new IllegalArgumentException("mkxp.json: preloadScript must be an array.");
        int start = text.indexOf('{');
        if (start < 0 || !text.trim().endsWith("}")) throw new IllegalArgumentException("mkxp.json: invalid object.");
        String rest = text.substring(start + 1);
        String withoutComments = maskComments(rest).trim();
        return text.substring(0, start + 1) + "\n  \"preloadScript\": [\"preload.rb\"]" + (withoutComments.equals("}") ? "\n" : ",\n") + rest;
    }
    private static String maskComments(String text) {
        StringBuilder result = new StringBuilder(text);
        boolean quoted = false, escaped = false;
        for (int i = 0; i < text.length(); i++) {
            char c = text.charAt(i);
            if (quoted) {
                if (escaped) escaped = false;
                else if (c == '\\') escaped = true;
                else if (c == '"') quoted = false;
            } else if (c == '"') quoted = true;
            else if (c == '/' && i + 1 < text.length() && text.charAt(i + 1) == '/') {
                while (i < text.length() && text.charAt(i) != '\n') result.setCharAt(i++, ' ');
            } else if (c == '/' && i + 1 < text.length() && text.charAt(i + 1) == '*') {
                result.setCharAt(i++, ' '); result.setCharAt(i, ' ');
                while (++i < text.length()) {
                    if (text.charAt(i) == '*' && i + 1 < text.length() && text.charAt(i + 1) == '/') { result.setCharAt(i++, ' '); result.setCharAt(i, ' '); break; }
                    result.setCharAt(i, ' ');
                }
            }
        }
        return result.toString();
    }
    public static byte[] profile(int edition) {
        if (edition < 0 || edition >= PROFILES.length) throw new IllegalArgumentException("Select the game edition.");
        return ("# encoding: UTF-8\nmodule PZHardcoreNuzlocke\n  module InstallConfig\n    LANGUAGE = :" + LANGUAGES[edition] + "\n    PROFILE = :" + PROFILES[edition] + "\n  end\nend\n").getBytes(StandardCharsets.UTF_8);
    }
}
