import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'package:gitjournal/core/note.dart';
import 'package:gitjournal/core/notes_folder.dart';
import 'package:gitjournal/core/sorting_mode.dart';

class NotesCache {
  final String filePath;
  final String notesBasePath;
  final bool enabled = true;

  NotesCache({@required this.filePath, @required this.notesBasePath});

  Future load(NotesFolder rootFolder) async {
    if (!enabled) return;
    var fileList = await loadFromDisk();

    var sep = Platform.pathSeparator;
    var notesBasePath = this.notesBasePath;
    if (!notesBasePath.endsWith(sep)) {
      notesBasePath += sep;
    }

    for (var fullFilePath in fileList) {
      var filePath = fullFilePath.substring(notesBasePath.length);
      var components = filePath.split(sep);

      //
      // Create required folders
      var parent = rootFolder;
      for (var i = 0; i < components.length - 1; i++) {
        var c = components.sublist(0, i + 1);
        var folderPath = p.join(this.notesBasePath, c.join(sep));

        var folders = parent.subFolders;
        var folderIndex = folders.indexWhere((f) => f.folderPath == folderPath);
        if (folderIndex != -1) {
          parent = folders[folderIndex];
          continue;
        }

        var subFolder = NotesFolder(parent, folderPath);
        parent.addFolder(subFolder);
        parent = subFolder;
      }

      var note = Note(parent, fullFilePath);
      note.load();
      parent.add(note);
    }
  }

  Future<void> buildCache(
    NotesFolder rootFolder,
    SortingMode sortingMode,
  ) async {
    if (!enabled) return;

    print("Saving the NotesCache");
    // FIXME: This could be optimized quite a bit
    var files = rootFolder.getAllNotes();
    assert(files.every((n) => n.loadState == NoteLoadState.Loaded));

    files.sort(sortingMode.sortingFunction());
    files = files.sublist(0, min(10, files.length));
    var fileList = files.map((f) => f.filePath).toList();

    return saveToDisk(fileList);
  }

  @visibleForTesting
  Future<List<String>> loadFromDisk() async {
    String contents = "";
    try {
      contents = await File(filePath).readAsString();
    } on FileSystemException catch (ex) {
      if (ex.osError.errorCode == 2 /* file not found */) {
        return [];
      }
      rethrow;
    }

    return json.decode(contents).cast<String>();
  }

  @visibleForTesting
  Future<void> saveToDisk(List<String> files) {
    var contents = json.encode(files);
    return File(filePath).writeAsString(contents);
  }
}