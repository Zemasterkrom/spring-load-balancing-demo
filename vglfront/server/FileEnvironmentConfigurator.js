const fs = require("fs");

/**
 * Copyright 2023 Zemasterkrom
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

/**
 * Utility class for creating environment files, similarly to Java with environment variables.
 *
 * In a dockerized or automated environment, this class may be of increased interest if a JavaScript application must
 * have access to environment variables when launching the application, which could be loaded from the environment file.
 *
 * Example : node FileEnvironmentConfigurator.js src/assets/environment.js %JSKEY% %JSVALUE% "window['environment']['%JSKEY%'] = %JSVALUE%;" testOne 0 testTwo 1
 */
class FileEnvironmentConfigurator {
  /**
   * Configuration file.
   */
  #file = null;

  /**
   * Key placeholder. This placeholder will be used to reference the current key in the environment template.
   */
  #keyPlaceholder = "";

  /**
   * Value placeholder. This placeholder will be used to reference the current value in the environment template.
   */
  #valuePlaceholder = "";

  /**
   * Content of the created environment file.
   */
  #content = "";

  /**
   * Environment template.
   */
  #environmentTemplate = "";

  /**
   * Constructor of FileEnvironmentConfigurator
   *
   * @param f File to load for the environment configuration
   * @param k Key placeholder
   * @param v Value placeholder
   * @param et Environment template
   */
  constructor(f, k, v, et) {
    if (!f || !k || !v || !et) {
      console.error("Can't pass null objects");
      process.exit(1);
    }

    if (k.length === 0) {
      console.error("The key placeholder can't be empty");
      process.exit(1);
    }

    if (v.length === 0) {
      console.error("The value placeholder can't be empty");
      process.exit(1);
    }

    if (et.length === 0) {
      console.error("The environment template can't be empty");
      process.exit(1);
    }

    try {
      if (fs.existsSync(f)) {
        const stat = fs.statSync(f);

        if (stat.isDirectory()) {
          console.error(`File ${f} is a directory`);
          process.exit(1);
        } else if (!fs.constants.W_OK & stat.mode) {
          console.error(`Can't write to ${f}`);
          process.exit(1);
        } else if (!fs.constants.R_OK & stat.mode) {
          console.error(`Can't read ${f}`);
          process.exit(1);
        }
      }
    } catch (e) {
      console.error(e.message);
      process.exit(1);
    }

    this.#file = f;
    this.#keyPlaceholder = k;
    this.#valuePlaceholder = v;
    this.#environmentTemplate = et;
  }

  /**
   * Define an environment variable in the environment file
   *
   * @param key Key currently being processed
   * @param value Value currently being processed
   */
  setEnvironmentVariable(key, value) {
    if (this.#content.length !== 0) this.#content += "\n";

    this.#content += this.#environmentTemplate
      .replace(this.#keyPlaceholder, key)
      .replace(this.#valuePlaceholder, value);
  }

  /**
    * Save the created environment file.
    *
    * @return true if success, false otherwise
    */
  async save() {
    try {
      await fs.promises.writeFile(this.#file, this.#content, 'utf8');
    } catch (err) {
      console.error(err);
      return false;
    }
    return true;
  }
}

async function main(args) {
  if (args.length < 4) {
    console.error('Usage: node FileEnvironmentConfigurator.js <Path to the environment file> <Key placeholder> <Value placeholder> <Environment template> <First key> <First value> ...');
    process.exit(1);
  }

  const ec = new FileEnvironmentConfigurator(args[0], args[1], args[2], args[3]);

  for (let i = 4; i < args.length; i += 2) {
    if (i + 1 < args.length) {
      ec.setEnvironmentVariable(args[i], args[i + 1]);
    }
  }

  await ec.save();
}

main(process.argv.slice(2));