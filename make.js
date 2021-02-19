// parse command line options
var minimist = require('minimist');
var mopts = {
    string: [
        'version',
        'stage',
        'taskId'
    ],
    boolean: [
        'public'
    ]
};

var options = minimist(process.argv, mopts);

// remove well-known parameters from argv before loading make
process.argv = options._;

// modules
var shell = require('shelljs');
var make = require('shelljs/make');
var path = require('path');
var os = require('os');
var cp = require('child_process');
var fs = require('fs');
var semver = require('semver');

// global paths
var sourcePath = path.join(__dirname, 'task');
var binariesPath = path.join(__dirname, '_artifacts', 'binaries');
var packagesPath = path.join(__dirname, '_artifacts', 'packages');

// add node modules .bin to path
var binPath = path.join(__dirname, 'node_modules', '.bin');
var separator = os.platform() === 'win32' ? ';' : ':';
var existing = process.env['PATH'];

if (existing)
    process.env['PATH'] = binPath + separator + existing;
else
    process.env['PATH'] = binPath;

// make targets
target.clean = function() {
    console.log('clean: cleaning binaries');

    shell.rm('-Rf', binariesPath);
    shell.mkdir('-p', binariesPath);
}

target.build = function() {
    target.clean();

    // build task
    console.log('build: building task');
    var taskOutputPath = path.join(binariesPath, 'task');
    shell.cp('-Rf', sourcePath, taskOutputPath);
    console.log('  task -> ' + taskOutputPath);

    // copy resources
    console.log('build: copying resources');
    ['README.md', 'LICENSE.txt', 'vss-extension.json'].forEach(function(file) {
        shell.cp('-Rf', path.join(__dirname, file), binariesPath);
        console.log('  ' + file + ' -> ' + path.join(binariesPath, file));
    });

    var imagesOutputPath = path.join(binariesPath, 'images')
    shell.mkdir('-p', imagesOutputPath);

    shell.cp('-Rf', path.join(__dirname, 'images', '*.png'), imagesOutputPath);
    console.log('  images -> ' + imagesOutputPath);

    // versioning
    console.log('build: versioning');
    if (options.version) {
        if (options.version === 'auto') {
            var ref = new Date(2000, 1, 1);
            var now = new Date();
            var major = 4
            var minor = Math.floor((now - ref) / 86400000);
            var patch = Math.floor(Math.floor(now.getSeconds() + (60 * (now.getMinutes() + (60 * now.getHours())))) * 0.5)
            options.version = major + '.' + minor + '.' + patch
        }
        
        if (!semver.valid(options.version)) {
            console.error('build', 'Invalid semver version: ' + options.version);
            process.exit(1);
        }
    }
    
    switch (options.stage) {
        case 'dev':
            options.taskId = 'BC5D1625-874F-4ABF-AC07-4A55EC6DCC76';
            options.public = false;
            break;
    }

    updateExtensionManifest(options);
    updateTaskManifest(options);
}

target.package = function() {
    console.log('package: packaging task');

    shell.exec('tfx extension create --root "' + binariesPath + '" --output-path "' + packagesPath +'"')
}

updateExtensionManifest = function(options) {
    var manifestPath = path.join(binariesPath, 'vss-extension.json')
    var manifest = JSON.parse(fs.readFileSync(manifestPath));
    
    if (options.version) {
        manifest.version = options.version;
    }
    
    if (options.stage) {
        manifest.id = manifest.id + '-' + options.stage
        manifest.name = manifest.name + ' (' + options.stage + ')'
    }

    manifest.public = options.public;
    
    fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 4));
}

updateTaskManifest = function(options) {
    var manifestPath = path.join(binariesPath, 'task', 'task.json')
    var manifest = JSON.parse(fs.readFileSync(manifestPath));
    
    if (options.version) {
        manifest.version.Major = semver.major(options.version);
        manifest.version.Minor = semver.minor(options.version);
        manifest.version.Patch = semver.patch(options.version);
    }

    manifest.helpMarkDown = 'v' + manifest.version.Major + '.' + manifest.version.Minor + '.' + manifest.version.Patch + ' - ' + manifest.helpMarkDown;
    
    if (options.stage) {
        manifest.friendlyName = manifest.friendlyName + ' (' + options.stage

        if (options.version) {
            manifest.friendlyName = manifest.friendlyName + ' ' + options.version
        }

        manifest.friendlyName = manifest.friendlyName + ')'
    }
    
    if (options.taskId) {
        manifest.id = options.taskId
    }
    
    fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 4));

    return manifest.version.Major + '.' + manifest.version.Minor + '.' + manifest.version.Patch
}