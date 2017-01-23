var gulp = require('gulp');
var gutil = require('gulp-util');
var debug = require('gulp-debug');
var del = require('del');
var merge = require('merge-stream');
var path = require('path');
var shell = require('shelljs');
var minimist = require('minimist');
var semver = require('semver');
var fs = require('fs');

var _buildRoot = path.join(__dirname, '_build');
var _packagesRoot = path.join(__dirname, '_packages');

gulp.task('default', ['build']);

gulp.task('build', ['clean'], function () {
    var extension = gulp.src(['README.md', 'LICENSE.txt', 'images/**/*', '!images/**/*.pdn', 'vss-extension.json'], { base: '.' })
        .pipe(debug({title: 'extension:'}))
        .pipe(gulp.dest(_buildRoot));
    var task = gulp.src('task/**/*', { base: '.' })
        .pipe(debug({title: 'task:'}))
        .pipe(gulp.dest(_buildRoot));
    
    return merge(extension, task);
});

gulp.task('clean', function() {
   return del([_buildRoot]);
});

gulp.task('test', ['build'], function() {
});

gulp.task('package', ['build'], function() {
    var args = minimist(process.argv.slice(2), {});
    var options = {
        version: args.version,
        stage: args.stage,
        public: args.public,
        taskId: args.taskId
    }

    if (options.version) {
        if (options.version === 'auto') {
            var ref = new Date(2000, 1, 1);
            var now = new Date();
            var major = 1
            var minor = Math.floor((now - ref) / 86400000);
            var patch = Math.floor(Math.floor(now.getSeconds() + (60 * (now.getMinutes() + (60 * now.getHours())))) * 0.5)
            options.version = major + '.' + minor + '.' + patch
        }
        
        if (!semver.valid(options.version)) {
            throw new gutil.PluginError('package', 'Invalid semver version: ' + options.version);
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
    
    shell.exec('tfx extension create --root "' + _buildRoot + '" --output-path "' + _packagesRoot +'"')
});

updateExtensionManifest = function(options) {
    var manifestPath = path.join(_buildRoot, 'vss-extension.json')
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
    var manifestPath = path.join(_buildRoot, 'task', 'task.json')
    var manifest = JSON.parse(fs.readFileSync(manifestPath));
    
    if (options.version) {
        manifest.version.Major = semver.major(options.version);
        manifest.version.Minor = semver.minor(options.version);
        manifest.version.Patch = semver.patch(options.version);
    }

    manifest.helpMarkDown = 'v' + manifest.version.Major + '.' + manifest.version.Minor + '.' + manifest.version.Patch + ', ' + manifest.helpMarkDown
    
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
}