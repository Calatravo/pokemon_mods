package org.pokemonzmods.installer;

import android.content.ContentResolver;
import android.database.Cursor;
import android.net.Uri;
import android.provider.DocumentsContract;
import java.io.*;
import java.util.*;

/** SAF access restricted to the directory explicitly picked by the user. */
final class DocumentTree implements InstallTransaction.Store {
    private final ContentResolver resolver;
    private final Uri tree;
    private final Map<String, Uri> cache = new HashMap<>();
    DocumentTree(ContentResolver resolver, Uri tree) {
        this.resolver = resolver; this.tree = tree;
        cache.put("", DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree)));
    }
    private Uri resolve(String path, boolean create, boolean directory) throws Exception {
        if (cache.containsKey(path)) return cache.get(path);
        int slash = path.lastIndexOf('/');
        String parentPath = slash < 0 ? "" : path.substring(0, slash);
        String name = path.substring(slash + 1);
        Uri parent = resolve(parentPath, create, true);
        if (parent == null) return null;
        Uri children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, DocumentsContract.getDocumentId(parent));
        try (Cursor c = resolver.query(children, new String[]{DocumentsContract.Document.COLUMN_DOCUMENT_ID, DocumentsContract.Document.COLUMN_DISPLAY_NAME, DocumentsContract.Document.COLUMN_MIME_TYPE}, null, null, null)) {
            if (c == null) throw new IOException("Cannot read folder: " + parentPath);
            while (c.moveToNext()) if (name.equals(c.getString(1))) {
                boolean isDirectory = DocumentsContract.Document.MIME_TYPE_DIR.equals(c.getString(2));
                if (isDirectory != directory) throw new IOException("Unexpected file type: " + path);
                Uri result = DocumentsContract.buildDocumentUriUsingTree(tree, c.getString(0));
                cache.put(path, result); return result;
            }
        }
        if (!create) return null;
        Uri result = DocumentsContract.createDocument(resolver, parent, directory ? DocumentsContract.Document.MIME_TYPE_DIR : "application/octet-stream", name);
        if (result == null) throw new IOException("Cannot create: " + path);
        cache.put(path, result); return result;
    }
    public byte[] read(String path) throws Exception {
        Uri document = resolve(path, false, false);
        if (document == null) return null;
        try (InputStream in = resolver.openInputStream(document)) { return bytes(in); }
    }
    static byte[] bytes(InputStream in) throws IOException {
        if (in == null) throw new IOException("Cannot open file");
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        byte[] buffer = new byte[65536]; int count;
        while ((count = in.read(buffer)) != -1) {
            out.write(buffer, 0, count);
            if (out.size() > 32 * 1024 * 1024) throw new IOException("File exceeds 32 MB limit");
        }
        return out.toByteArray();
    }
    public void write(String path, byte[] data) throws Exception {
        Uri document = resolve(path, true, false);
        try (OutputStream out = resolver.openOutputStream(document, "wt")) {
            if (out == null) throw new IOException("Cannot write: " + path);
            out.write(data);
        }
    }
    public void delete(String path) throws Exception {
        Uri document = resolve(path, false, false);
        if (document != null && !DocumentsContract.deleteDocument(resolver, document)) throw new IOException("Cannot remove: " + path);
        cache.remove(path);
    }
}
