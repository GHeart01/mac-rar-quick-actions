#!/usr/bin/env python3
"""Generate the two Finder Quick Action bundles in ./workflows.

Each bundle is an Automator "Quick Action" (a Services-menu workflow) with a
single "Run Shell Script" action that passes the selected Finder items as
arguments to the installed rartool.sh.

Run from the repo root:  python3 tools/build_workflows.py
"""
import os
import plistlib
import shutil
import uuid

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "workflows")
TOOL = '"$HOME/Library/Application Support/RarQuickActions/rartool.sh"'

WORKFLOWS = [
    {
        "name": "Extract RAR",
        "command": f'exec {TOOL} extract "$@"',
        "file_types": ["com.rarlab.rar-archive"],
        "symbol": "archivebox",
    },
    {
        "name": "Compress to RAR",
        "command": f'exec {TOOL} compress "$@"',
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


def main():
    for wf in WORKFLOWS:
        bundle = os.path.join(OUT, wf["name"] + ".workflow")
        shutil.rmtree(bundle, ignore_errors=True)
        contents = os.path.join(bundle, "Contents")
        os.makedirs(contents)
        with open(os.path.join(contents, "Info.plist"), "wb") as f:
            plistlib.dump(info_plist(wf), f)
        with open(os.path.join(contents, "document.wflow"), "wb") as f:
            plistlib.dump(document(wf), f)
        print("wrote", os.path.relpath(bundle, ROOT))


if __name__ == "__main__":
    main()
