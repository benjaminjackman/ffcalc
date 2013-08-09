//Born on the 4th of July.

var _ = require('underscore');

module.exports = function (grunt) {

  //External tasks
  grunt.loadNpmTasks('grunt-bower-task');
  grunt.loadNpmTasks('grunt-contrib-clean');
  grunt.loadNpmTasks('grunt-contrib-coffee');
  grunt.loadNpmTasks('grunt-contrib-less');
  grunt.loadNpmTasks('grunt-contrib-watch');
  grunt.loadNpmTasks('grunt-copy-to');
  grunt.loadNpmTasks('grunt-express');
  grunt.loadNpmTasks('grunt-shell');

  //Helper functions
  function log() {
    grunt.log.writeln.apply(
      grunt.log,
      _.toArray(arguments).map(function (x) {
        return _.isObject(x) || _.isArray(x) ? JSON.stringify(x) : x
      })
    );
  }


  grunt.initConfig({
    bower: {
      install: {
      }
    },

    express: {
      server: {
        options: {
          port: 3000,
          bases: ["target/site"]
        }
      }
    },

    clean: {
      bower: ['lib', 'components'],
      coffee: ['target/site/scripts/coffee'],
      less: ['target/site/styles/less'],
      templates: ['target/site/*.html']
    },

    copyto: {
      bootstrapImg: {
        files: [
          {cwd: "lib/bootstrap", src: "*.png", dest: "target/site/styles/lib/img/"}
        ]}
    },

    less: {
      site: {
        src: 'src/site/less/**/*.less',
        dest: 'target/site/styles/less/less.css'
      }
    },

    coffee: {
      site: {
        expand: true,
        flatten: true,
        src: 'src/site/coffee/**/*.coffee',
        dest: 'target/site/scripts/coffee',
        ext: '.js'
      }
    },

    watch: {
      //Build on coffee file changes
      coffee: {
        files: 'src/site/coffee/**/*.coffee',
        tasks: ['coffee', 'templates']
      },
      //Build on js file changes
      js: {
        files: 'src/site/js/**/*.js',
        tasks: ['templates']
      },
      //Build on js file changes
      css: {
        files: 'src/site/css/**/*.css',
        tasks: ['templates']
      },
      //Build on js file changes
      less: {
        files: 'src/site/less/**/*.less',
        tasks: ['less', 'templates']
      },
      //Build on changes to html template files
      templates: {
        files: ['grunt-templates/**/*.html'],
        tasks: ['templates']
      }
    }
  });

  grunt.registerTask('templates', 'Fills in Html Templates', function () {
    //Get the name of all the html files.
//    var templs = grunt.file.expandMapping(htmlSrc, htmlOut, {cwd:'src/site/html'})
    var templs = grunt.file.expand({cwd: 'src/site/grunt-templates'}, '**/*.html');
    var scripts = _.uniq(grunt.file.expand(
      {cwd: "target/site"},
      [ 'scripts/lib/jquery/jquery.js',
        'scripts/lib/angular/angular.js',
        'scripts/lib/**/*.js',
        'scripts/js/**/*.js',
        'scripts/coffee/**/*.js',
        'scripts/ts/**/*.js']));
    var scriptsTmpl = scripts.map(
      function (f) {
        return '<script src="' + f + '"></script>';
      }
    ).join("\n");


    var stylesTmpl = grunt.file.expand({cwd: "target/site"}, ['styles/lib/**/*.css', 'styles/css/**/*.css', 'styles/less/**/*.css']).map(
      function (f) {
        return '<link rel="stylesheet" href="' + f + '"/>';
      }
    ).join("\n");

    templs.forEach(function (f) {
      var cfg = {
        js: scriptsTmpl,
        css: stylesTmpl
      };
      var src = 'src/site/grunt-templates/' + f;
      var dest = 'target/site/' + f;
      grunt.file.write(dest, grunt.template.process(grunt.file.read(src), {data: cfg}));
    });
  });

  //Clears then Downloads bower managed dependencies
  grunt.registerTask('update', ['clean:bower', 'bower:install']);
  //Cleans generated files
  grunt.registerTask('cleangen', ['clean:coffee', 'clean:less', 'clean:templates']);
  //Compiles needed files to the site folder
  grunt.registerTask('compile', ['cleangen', 'coffee', 'less', 'templates']);
  //loops and recompiles / tests on every source file change.
  grunt.registerTask('loop', ['compile', 'express', 'watch']);
  //by default do a compile
  grunt.registerTask('default', ['compile']);


};

