import org.pokemonzmods.installer.*;
import java.nio.charset.StandardCharsets;
import java.util.*;

public class InstallerTest {
    static byte[] bytes(String s) { return s.getBytes(StandardCharsets.UTF_8); }
    static void check(boolean ok, String message) { if (!ok) throw new AssertionError(message); }
    static class Memory implements InstallTransaction.Store {
        Map<String, byte[]> files = new HashMap<>();
        String failPath; boolean failed;
        public byte[] read(String path) { return files.get(path); }
        public void write(String path, byte[] data) throws Exception {
            files.put(path, data);
            if (path.equals(failPath) && !failed) { failed = true; throw new Exception("injected partial write failure"); }
        }
        public void delete(String path) { files.remove(path); }
    }
    public static void main(String[] args) throws Exception {
        String snippet = "# BEGIN POKEMON_MODS HARDCORE_NUZLOCKE\nload File.expand_path('Mods/HardcoreNuzlocke/loader.rb')\n# END POKEMON_MODS HARDCORE_NUZLOCKE";
        String first = InstallLogic.preload("# user preload\n", snippet);
        check(first.equals(InstallLogic.preload(first, snippet)), "Repeated install duplicates loader");
        check(first.startsWith("# user preload"), "Custom preload lost");
        String cfg = "{\n// comment\n\"preloadScript\": [\"other.rb\"]\n}";
        String updated = InstallLogic.mkxp(cfg);
        check(updated.contains("\"other.rb\", \"preload.rb\""), "Other preload lost");
        check(updated.equals(InstallLogic.mkxp(updated)), "mkxp not idempotent");
        check(!InstallLogic.mkxp("{}").contains(","), "Invalid empty JSON object");
        check(InstallLogic.mkxp("{\"preloadScript\":[\"other.rb\"]}").equals("{\"preloadScript\":[\"other.rb\", \"preload.rb\"]}"), "Inline config not preserved");
        check(!InstallLogic.mkxp("{/* empty */}").contains(","), "Comment-only object has trailing comma");
        try { InstallLogic.mkxp("{\n\"preloadScript\": \"custom.rb\"\n}"); throw new AssertionError("Scalar accepted"); } catch (IllegalArgumentException expected) { }
        for (int i = 0; i < 3; i++) check(new String(InstallLogic.profile(i), StandardCharsets.UTF_8).contains(InstallLogic.PROFILES[i]), "Wrong edition");
        Memory store = new Memory();
        store.files.put("preload.rb", bytes("original")); store.files.put("Data/Scripts.rxdata", bytes("game")); store.files.put("Game.rxdata", bytes("save"));
        LinkedHashMap<String, byte[]> payload = new LinkedHashMap<>();
        payload.put("Mods/HardcoreNuzlocke/loader.rb", bytes("mod")); payload.put("preload.rb", bytes("patched"));
        store.failPath = "preload.rb";
        try { InstallTransaction.apply(store, payload, "backup1"); throw new AssertionError("Write failure hidden"); } catch (Exception expected) { }
        check(Arrays.equals(store.read("preload.rb"), bytes("original")), "Partial write not restored");
        check(store.read("Mods/HardcoreNuzlocke/loader.rb") == null, "New file not rolled back");
        check(Arrays.equals(store.read("backup1/preload.rb"), bytes("original")), "Backup missing");
        store.failPath = null;
        InstallTransaction.apply(store, payload, "backup2");
        check(Arrays.equals(store.read("preload.rb"), bytes("patched")), "Install failed");
        check(Arrays.equals(store.read("Data/Scripts.rxdata"), bytes("game")), "Game data changed");
        check(Arrays.equals(store.read("Game.rxdata"), bytes("save")), "Save changed");
        System.out.println("PASS: merge/idempotency, editions, backup, partial-write rollback, game/save preservation");
    }
}
