package org.pokemonzmods.installer;

import android.app.*;
import android.content.*;
import android.net.Uri;
import android.os.Bundle;
import android.view.*;
import android.widget.*;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.text.SimpleDateFormat;
import java.util.*;

public final class MainActivity extends Activity {
    private Uri tree;
    private TextView status, folder;
    private Spinner edition;
    private Button choose, install, verify;
    private boolean busy;
    private String t(String es, String en, String fr) {
        String lang = Locale.getDefault().getLanguage();
        return lang.equals("es") ? es : lang.equals("fr") ? fr : en;
    }
    private TextView label(LinearLayout layout, String text, int size) {
        TextView view = new TextView(this); view.setText(text); view.setTextSize(size);
        view.setPadding(0, 12, 0, 12); layout.addView(view); return view;
    }
    private Button button(LinearLayout layout, String text, View.OnClickListener action) {
        Button view = new Button(this); view.setText(text); view.setAllCaps(false); view.setOnClickListener(action); layout.addView(view); return view;
    }
    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        getWindow().getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR | View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR);
        ScrollView scroll = new ScrollView(this);
        LinearLayout layout = new LinearLayout(this); layout.setOrientation(LinearLayout.VERTICAL); layout.setPadding(28, 24, 28, 40);
        scroll.addView(layout); setContentView(scroll);
        scroll.setOnApplyWindowInsetsListener((view, insets) -> {
            view.setPadding(insets.getSystemWindowInsetLeft(), insets.getSystemWindowInsetTop(), insets.getSystemWindowInsetRight(), insets.getSystemWindowInsetBottom());
            return insets;
        });
        label(layout, "Pokémon Z Mods", 28);
        label(layout, t("Instalador Android · versión de prueba", "Android installer · test build", "Installateur Android · version de test"), 16);
        label(layout, t("Para JoiPlay y Kirin. Cierra el juego antes de instalar. Necesitas el juego ya descomprimido.", "For JoiPlay and Kirin. Close the game before installing. Extract the game first.", "Pour JoiPlay et Kirin. Fermez le jeu avant l’installation. Décompressez d’abord le jeu."), 16);
        choose = button(layout, t("1. Elegir carpeta del juego", "1. Choose game folder", "1. Choisir le dossier du jeu"), v -> {
            Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT_TREE);
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_WRITE_URI_PERMISSION | Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION);
            startActivityForResult(intent, 10);
        });
        folder = label(layout, t("Selecciona la carpeta que contiene Game.exe, no el ZIP ni la carpeta Mods.", "Select the folder containing Game.exe, not the ZIP or Mods folder.", "Sélectionnez le dossier contenant Game.exe, pas le ZIP ni le dossier Mods."), 15);
        label(layout, t("2. Edición del juego", "2. Game edition", "2. Édition du jeu"), 18);
        edition = new Spinner(this);
        ArrayAdapter<String> options = new ArrayAdapter<>(this, android.R.layout.simple_spinner_dropdown_item, new String[]{t("Selecciona la edición…", "Select edition…", "Choisissez l’édition…"), "Español · 2.18", "English · 2.13", "Français · 2.12 + Patch 1"});
        edition.setAdapter(options); layout.addView(edition);
        install = button(layout, t("3. Instalar / actualizar mod", "3. Install / update mod", "3. Installer / mettre à jour"), v -> {
            if (tree == null || edition.getSelectedItemPosition() == 0) { status.setText(t("Elige la carpeta y la edición primero.", "Choose a folder and edition first.", "Choisissez d’abord le dossier et l’édition.")); return; }
            final int selected = edition.getSelectedItemPosition() - 1;
            new AlertDialog.Builder(this).setTitle(t("Instalar el mod", "Install the mod", "Installer le mod"))
                .setMessage(t("Cierra JoiPlay/Kirin. Se guardará una copia de los archivos que se cambien. Tus partidas y Data/Scripts.rxdata se conservan.", "Close JoiPlay/Kirin. Changed files will be backed up. Saves and Data/Scripts.rxdata are preserved.", "Fermez JoiPlay/Kirin. Les fichiers modifiés seront sauvegardés. Les parties et Data/Scripts.rxdata sont conservés."))
                .setNegativeButton(android.R.string.cancel, null).setPositiveButton(t("Instalar", "Install", "Installer"), (d, which) -> work(() -> installMod(selected))).show();
        });
        verify = button(layout, t("4. Comprobar instalación", "4. Check installation", "4. Vérifier l’installation"), v -> work(this::verifyMod));
        status = label(layout, t("Abre el juego desde JoiPlay o Kirin después de instalar. Randomlocke se configura después de la selección inicial de Nuzlocke, no en el título.\n\nKirin: ejecución todavía no confirmada.", "After installing, open the game in JoiPlay or Kirin. Configure Randomlocke after the initial Nuzlocke selection, not on the title screen.\n\nKirin: runtime compatibility is not confirmed.", "Après l’installation, ouvrez le jeu dans JoiPlay ou Kirin. Randomlocke se configure après le choix initial de Nuzlocke, pas à l’écran titre.\n\nKirin : exécution non confirmée."), 16);
        status.setTextIsSelectable(true);
        String saved = getPreferences(0).getString("tree", null);
        if (saved != null) { tree = Uri.parse(saved); folder.setText(android.provider.DocumentsContract.getTreeDocumentId(tree)); edition.setSelection(getPreferences(0).getInt("edition", 0)); }
    }
    @Override protected void onActivityResult(int request, int result, Intent data) {
        super.onActivityResult(request, result, data);
        if (request != 10 || result != RESULT_OK || data == null) return;
        tree = data.getData();
        try {
            getContentResolver().takePersistableUriPermission(tree, data.getFlags() & (Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_WRITE_URI_PERMISSION));
            getPreferences(0).edit().putString("tree", tree.toString()).putInt("edition", 0).apply();
            edition.setSelection(0); folder.setText(android.provider.DocumentsContract.getTreeDocumentId(tree));
            work(() -> {
                DocumentTree store = new DocumentTree(getContentResolver(), tree);
                validateGame(store);
                int found = InstallLogic.detect(store.read("Data/Scripts.rxdata"));
                runOnUiThread(() -> edition.setSelection(found + 1));
                return found < 0 ? t("Carpeta válida. Confirma la edición: los archivos no coinciden con una edición reconocida automáticamente.", "Valid folder. Confirm the edition: these files were not recognized automatically.", "Dossier valide. Confirmez l’édition : ces fichiers ne sont pas reconnus automatiquement.") : t("Edición detectada. Ya puedes instalar.", "Edition detected. Ready to install.", "Édition détectée. Vous pouvez installer.");
            });
        } catch (Exception error) { status.setText(error.toString()); }
    }
    private interface Job { String run() throws Exception; }
    private void work(Job job) {
        if (busy) return;
        busy = true; choose.setEnabled(false); install.setEnabled(false); verify.setEnabled(false); edition.setEnabled(false);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        status.setText(t("Comprobando archivos…", "Checking files…", "Vérification des fichiers…"));
        new Thread(() -> {
            String result;
            try { result = job.run(); } catch (Exception error) { android.util.Log.e("PokemonZModsInstaller", "Operation failed", error); result = t("No se ha completado: ", "Not completed: ", "Opération incomplète : ") + error.getMessage(); }
            final String message = result;
            runOnUiThread(() -> { status.setText(message); busy = false; choose.setEnabled(true); install.setEnabled(true); verify.setEnabled(true); edition.setEnabled(true); getWindow().clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON); });
        }, "mod-installer").start();
    }
    @Override public void onBackPressed() { if (!busy) super.onBackPressed(); }
    private void validateGame(DocumentTree store) throws Exception {
        for (String path : new String[]{"Game.exe", "Game.ini", "Data/Scripts.rxdata", "preload.rb", "mkxp.json"})
            if (store.read(path) == null) throw new IOException(t("Falta ", "Missing ", "Fichier absent : ") + path + t(". Elige la carpeta que contiene Game.exe.", ". Choose the folder containing Game.exe.", ". Choisissez le dossier contenant Game.exe."));
    }
    private byte[] asset(String path) throws Exception { try (InputStream in = getAssets().open(path)) { return DocumentTree.bytes(in); } }
    private static String text(byte[] data) { return new String(data, StandardCharsets.UTF_8); }
    private void payload(String path, LinkedHashMap<String, byte[]> files) throws Exception {
        String[] children = getAssets().list(path);
        if (children != null && children.length > 0) { for (String child : children) payload(path + "/" + child, files); }
        else files.put("Mods/HardcoreNuzlocke/" + path.substring("mod/".length()), asset(path));
    }
    private String installMod(int selected) throws Exception {
        DocumentTree store = new DocumentTree(getContentResolver(), tree); validateGame(store);
        int detected = InstallLogic.detect(store.read("Data/Scripts.rxdata"));
        if (detected >= 0 && detected != selected) throw new IOException(t("La edición elegida no coincide con el juego.", "Selected edition does not match the game.", "L’édition choisie ne correspond pas au jeu."));
        LinkedHashMap<String, byte[]> files = new LinkedHashMap<>(); payload("mod", files);
        files.put("Mods/HardcoreNuzlocke/Config/install_profile.rb", InstallLogic.profile(selected));
        files.put("preload.rb", InstallLogic.preload(text(store.read("preload.rb")), text(asset("preload-snippet.rb"))).getBytes(StandardCharsets.UTF_8));
        files.put("mkxp.json", InstallLogic.mkxp(text(store.read("mkxp.json"))).getBytes(StandardCharsets.UTF_8));
        // A fresh log prevents a previous installation's PASS from being mistaken for this run.
        files.put("Mods/HardcoreNuzlocke/nuzlocke.log", new byte[0]);
        String backup = "PokemonZMods-backups/" + new SimpleDateFormat("yyyyMMdd-HHmmss-SSS", Locale.ROOT).format(new Date());
        InstallTransaction.apply(store, files, backup);
        getPreferences(0).edit().putInt("edition", selected + 1).apply();
        return t("Instalación completada y archivos verificados.\n\n", "Installation completed and files verified.\n\n", "Installation terminée et fichiers vérifiés.\n\n") + t("Copia de seguridad: ", "Backup: ", "Sauvegarde : ") + backup + "\n\n" + t("Abre Game.exe desde JoiPlay o Kirin. Después vuelve y pulsa Comprobar instalación. Kirin sigue sin estar validado.", "Open Game.exe in JoiPlay or Kirin. Then return and tap Check installation. Kirin remains unverified.", "Ouvrez Game.exe dans JoiPlay ou Kirin, puis revenez vérifier l’installation. Kirin reste non validé.");
    }
    private String verifyMod() throws Exception {
        if (tree == null) throw new IOException(t("Elige la carpeta del juego.", "Choose the game folder.", "Choisissez le dossier du jeu."));
        DocumentTree store = new DocumentTree(getContentResolver(), tree);
        LinkedHashMap<String, byte[]> files = new LinkedHashMap<>(); payload("mod", files);
        files.remove("Mods/HardcoreNuzlocke/Config/install_profile.rb");
        for (Map.Entry<String, byte[]> entry : files.entrySet()) if (!Arrays.equals(entry.getValue(), store.read(entry.getKey())))
            throw new IOException(t("Falta o difiere: ", "Missing or changed: ", "Absent ou modifié : ") + entry.getKey());
        byte[] preload = store.read("preload.rb");
        if (preload == null || !text(preload).contains(text(asset("preload-snippet.rb")).trim())) throw new IOException("preload.rb: loader missing or changed");
        byte[] profile = store.read("Mods/HardcoreNuzlocke/Config/install_profile.rb");
        int selected = -1;
        for (int i = 0; i < 3; i++) if (Arrays.equals(profile, InstallLogic.profile(i))) selected = i;
        if (selected < 0) throw new IOException("install_profile.rb: missing or changed");
        byte[] mkxp = store.read("mkxp.json");
        if (mkxp == null || !InstallLogic.mkxp(text(mkxp)).equals(text(mkxp))) throw new IOException("mkxp.json: preload.rb is not enabled");
        byte[] log = store.read("Mods/HardcoreNuzlocke/nuzlocke.log");
        String history = log == null ? "" : text(log);
        int lastBoot = Math.max(history.lastIndexOf("Deferred runtime hook installed"), history.lastIndexOf("[PRELOAD ERROR]"));
        if (lastBoot >= 0) history = history.substring(lastBoot);
        if (history.contains("Installation self-test PASS (14 hooks)") && history.contains("Compatibility profile PASS: " + InstallLogic.PROFILES[selected]) && !history.contains("ERROR") && !history.contains("FAIL"))
            return t("Archivos correctos.\nCarga del mod confirmada en el último registro:\nPASS (14 hooks)\nCompatibility profile PASS\n\nEsto confirma la carga, no una prueba de toda la partida.", "Files correct.\nMod loaded in the latest log:\nPASS (14 hooks)\nCompatibility profile PASS\n\nThis confirms loading, not a full playthrough.", "Fichiers corrects.\nChargement confirmé dans le dernier journal :\nPASS (14 hooks)\nCompatibility profile PASS\n\nCela confirme le chargement, pas une partie complète.");
        return t("Archivos correctos. La carga del mod todavía no está confirmada. Abre el juego, ciérralo y vuelve a comprobar. Si falla, conserva nuzlocke.log.", "Files correct. Mod loading is not confirmed yet. Open the game, close it and check again. If it fails, keep nuzlocke.log.", "Fichiers corrects. Le chargement du mod n’est pas encore confirmé. Ouvrez le jeu, fermez-le, puis vérifiez à nouveau. En cas d’échec, conservez nuzlocke.log.");
    }
}
