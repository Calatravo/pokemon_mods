package org.pokemonzmods.installer;

import java.nio.charset.StandardCharsets;
import java.util.*;

/** Only writes the supplied mod/config paths. Backups precede every game write. */
public final class InstallTransaction {
    public interface Store {
        byte[] read(String path) throws Exception; // null means absent
        void write(String path, byte[] data) throws Exception;
        void delete(String path) throws Exception;
    }
    public static void apply(Store store, LinkedHashMap<String, byte[]> files, String backup) throws Exception {
        LinkedHashMap<String, byte[]> originals = new LinkedHashMap<>();
        StringBuilder manifest = new StringBuilder("Restore existing files from this directory to the game directory.\nFiles marked NEW did not exist before this installation.\n\n");
        for (String path : files.keySet()) {
            if (!(path.equals("preload.rb") || path.equals("mkxp.json") || path.startsWith("Mods/HardcoreNuzlocke/")) || path.contains(".."))
                throw new IllegalArgumentException("Unexpected destination: " + path);
            byte[] old = store.read(path);
            originals.put(path, old);
            manifest.append(old == null ? "NEW " : "RESTORE ").append(path).append('\n');
            if (old != null) {
                store.write(backup + "/" + path, old);
                if (!Arrays.equals(old, store.read(backup + "/" + path))) throw new Exception("Backup verification failed: " + path);
            }
        }
        store.write(backup + "/RESTORE.txt", manifest.toString().getBytes(StandardCharsets.UTF_8));
        List<String> attempted = new ArrayList<>();
        try {
            for (Map.Entry<String, byte[]> file : files.entrySet()) {
                attempted.add(file.getKey()); // include a possibly partially written file
                store.write(file.getKey(), file.getValue());
                if (!Arrays.equals(file.getValue(), store.read(file.getKey()))) throw new Exception("Verification failed: " + file.getKey());
            }
        } catch (Exception error) {
            boolean restored = true;
            Collections.reverse(attempted);
            for (String path : attempted) {
                try {
                    byte[] old = originals.get(path);
                    if (old == null) store.delete(path); else store.write(path, old);
                } catch (Exception rollbackError) { restored = false; error.addSuppressed(rollbackError); }
            }
            throw new Exception((restored ? "Installation failed; previous files restored. " : "Installation failed; restore the backup manually: " + backup + ". ") + error.getMessage(), error);
        }
    }
}
