'use strict';
var fs = require('fs');
var path = require('path');

var rootdir = process.argv[2];

function replace_string_in_file(filename, to_replace, replace_with) {
    var data = fs.readFileSync(filename, 'utf8');
    var result = data.replace(to_replace, replace_with);
    fs.writeFileSync(filename, result, 'utf8');
}

var PLUGIN_NAME = 'cordova-plugin-twilio-video';
var PLUGIN_PACKAGE = 'org.apache.cordova.twiliovideo';
var CORDOVA_SOURCES_PATH = path.join('platforms', 'src', 'org', 'apache', 'cordova', 'twiliovideo');

var androidPluginConfigPath = path.join('plugins', 'android.json');
var androidPluginConfig = JSON.parse(fs.readFileSync(androidPluginConfigPath, 'utf8'));

var appPackageName = androidPluginConfig.installed_plugins[PLUGIN_NAME].PACKAGE_NAME;
// Add java files where you want to add R.java imports in the following array


var filesToReplace = [
    path.join(CORDOVA_SOURCES_PATH, 'TwilioVideoActivity.java'),
    path.join(CORDOVA_SOURCES_PATH, 'SettingsActivity.java'),
    path.join(CORDOVA_SOURCES_PATH, 'Dialog.java')
];

filesToReplace.forEach(function(file) {
    if (fs.existsSync(file)) {
        console.log('Android platform available !');
        //Getting the package name from the android.json file,replace with your plugin's id
        console.log('With the package name: ' + appPackageName);
        console.log('Adding import for R.java');
        replace_string_in_file(file, 'package '+ PLUGIN_PACKAGE + ';', 'package ' + PLUGIN_PACKAGE + ';\n\nimport ' + appPackageName + '.R;');

    } else {
        console.log('No android platform found! :(');
    }
});