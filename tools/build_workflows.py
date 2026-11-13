#!/usr/bin/env python3
"""Generate the Finder Quick Action bundles.

Each bundle is an Automator "Quick Action" (a Services-menu workflow) with a
single action that hands the selected Finder items to the installed rartool.sh:

  workflows/        use the RarQuickActions.action Automator action, which
                    reports rar's percentage to the menu-bar gear. Needs
                    Automator ▸ Third Party Automator Actions to be allowed.
  workflows-basic/  use Apple's "Run Shell Script" action. Always works, but
                    the gear can only show "0% completed".
  action/Probe.workflow
                    runs the custom action in "probe" mode; install.sh uses it
                    to check whether third-party actions are allowed.

install.sh points ActionBundlePath at the installed action for each user.

Run from the repo root:  python3 tools/build_workflows.py
"""
import os
import plistlib
import shutil
import uuid

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# Placeholder; install.sh replaces it with the real path in the user's home.
ACTION_PATH = "~/Library/Automator/RarQuickActions.action"
TOOL = '"$HOME/Library/Application Support/RarQuickActions/rartool.sh"'

WORKFLOWS = [
    {
        "name": "Extract RAR",
        "command": f'exec {TOOL} extract "$@"',
        "mode": "extract",
        "label": "Extracting RAR",
        "file_types": ["com.rarlab.rar-archive"],
        "symbol": "archivebox",
    },
    {
        "name": "Compress to RAR",
        "command": f'exec {TOOL} compress "$@"',
        "mode": "compress",
        "label": "Compressing to RAR",
        "file_types": ["public.item"],
        "symbol": "archivebox.fill",
    },
]


def u():
    return str(uuid.uuid4()).upper()


def info_plist(wf):
    return {
        "NSServices": [
            {
                "NSBackgroundColorName": "background",
                "NSIconName": "NSActionTemplate",
                "NSMenuItem": {"default": wf["name"]},
                "NSMessage": "runWorkflowAsService",
                "NSRequiredContext": {"NSApplicationIdentifier": "com.apple.finder"},
                "NSSendFileTypes": wf["file_types"],
            }
        ]
    }


def arg(name, default):
    return {"default value": default, "name": name, "required": "0", "type": "0"}


def rar_action(mode, label):
    """The custom RarQuickActions.action (see action/RarQuickAction.m)."""
    return {
        "AMAccepts": {"Container": "List", "Optional": True, "Types": ["com.apple.cocoa.path"]},
        "AMActionVersion": "1.0",
        "AMApplication": ["Finder"],
        "AMParameterProperties": {"mode": {}},
        "AMProvides": {"Container": "List", "Types": ["com.apple.cocoa.path"]},
        "ActionBundlePath": ACTION_PATH,
        "ActionName": label,
        "ActionParameters": {"mode": mode},
        "BundleIdentifier": "io.github.gheart01.RarQuickActions",
        "CFBundleVersion": "1.0",
        "CanShowSelectedItemsWhenRun": False,
        "CanShowWhenRun": False,
        "Category": ["AMCategoryFilesAndFolders"],
        "Class Name": "RarQuickAction",
        "InputUUID": u(),
        "Keywords": [],
        "OutputUUID": u(),
        "UUID": u(),
        "UnlocalizedApplications": ["Finder"],
        "arguments": {"0": {"default value": "extract", "name": "mode", "required": "0", "type": "0", "uuid": "0"}},
        "isViewVisible": 1,
        "location": "309.000000:305.000000",
    }


def document(wf):
    args = [
        arg("inputMethod", 0),
        arg("CheckedForUserDefaultShell", False),
        arg("source", ""),
        arg("COMMAND_STRING", ""),
        arg("shell", "/bin/sh"),
    ]
    arguments = {}
    for i, a in enumerate(args):
        a["uuid"] = str(i)
        arguments[str(i)] = a

    action = {
        "AMAccepts": {"Container": "List", "Optional": True, "Types": ["com.apple.cocoa.path"]},
        "AMActionVersion": "2.0.3",
        "AMApplication": ["Automator"],
        "AMParameterProperties": {k: {} for k in
                                  ("COMMAND_STRING", "CheckedForUserDefaultShell", "inputMethod", "shell", "source")},
        "AMProvides": {"Container": "List", "Types": ["com.apple.cocoa.string"]},
        "ActionBundlePath": "/System/Library/Automator/Run Shell Script.action",
        "ActionName": "Run Shell Script",
        "ActionParameters": {
            "COMMAND_STRING": wf["command"],
            "CheckedForUserDefaultShell": True,
            "inputMethod": 1,  # pass input as arguments ("$@")
            "shell": "/bin/bash",
            "source": "",
        },
        "BundleIdentifier": "com.apple.RunShellScript",
        "CFBundleVersion": "2.0.3",
        "CanShowSelectedItemsWhenRun": False,
        "CanShowWhenRun": True,
        "Category": ["AMCategoryUtilities"],
        "Class Name": "RunShellScriptAction",
        "InputUUID": u(),
        "Keywords": ["Shell", "Script", "Command", "Run", "Unix"],
        "OutputUUID": u(),
        "UUID": u(),
        "UnlocalizedApplications": ["Automator"],
        "arguments": arguments,
        "conversionLabel": 0,
        "isViewVisible": 1,
        "location": "309.000000:305.000000",
        "nibPath": "/System/Library/Automator/Run Shell Script.action/Contents/Resources/Base.lproj/main.nib",
    }

    return {
        "AMApplicationBuild": "534",
        "AMApplicationVersion": "2.10",
        "AMDocumentVersion": "2",
        "actions": [{"action": action, "isViewVisible": 1}],
        "connectors": {},
        "workflowMetaData": {
            "applicationBundleID": "com.apple.finder",
            "applicationBundleIDsByPath": {"/System/Library/CoreServices/Finder.app": "com.apple.finder"},
            "applicationPath": "/System/Library/CoreServices/Finder.app",
            "applicationPaths": ["/System/Library/CoreServices/Finder.app"],
            "inputTypeIdentifier": "com.apple.Automator.fileSystemObject",
            "outputTypeIdentifier": "com.apple.Automator.nothing",
            "presentationMode": 15,
            "processesInput": False,
            "serviceApplicationBundleID": "com.apple.finder",
            "serviceApplicationPath": "/System/Library/CoreServices/Finder.app",
            "serviceInputTypeIdentifier": "com.apple.Automator.fileSystemObject",
            "serviceOutputTypeIdentifier": "com.apple.Automator.nothing",
            "serviceProcessesInput": False,
            "systemImageName": wf["symbol"],
            "useAutomaticInputType": False,
            "workflowTypeIdentifier": "com.apple.Automator.servicesMenu",
        },
    }


def write_bundle(path, info, doc):
    shutil.rmtree(path, ignore_errors=True)
    contents = os.path.join(path, "Contents")
    os.makedirs(contents)
    with open(os.path.join(contents, "Info.plist"), "wb") as f:
        plistlib.dump(info, f)
    with open(os.path.join(contents, "document.wflow"), "wb") as f:
        plistlib.dump(doc, f)
    print("wrote", os.path.relpath(path, ROOT))


def main():
    for wf in WORKFLOWS:
        # Basic: Apple's Run Shell Script action.
        write_bundle(os.path.join(ROOT, "workflows-basic", wf["name"] + ".workflow"),
                     info_plist(wf), document(wf))
        # Default: the custom action, with live progress in the gear.
        doc = document(wf)
        doc["actions"][0]["action"] = rar_action(wf["mode"], wf["label"])
        write_bundle(os.path.join(ROOT, "workflows", wf["name"] + ".workflow"), info_plist(wf), doc)

    probe = {"name": "Probe", "command": "", "file_types": ["public.item"], "symbol": "archivebox"}
    doc = document(probe)
    doc["actions"][0]["action"] = rar_action("probe", "Probe")
    write_bundle(os.path.join(ROOT, "action", "Probe.workflow"), info_plist(probe), doc)


if __name__ == "__main__":
    main()
