const fs = require("fs");

/**
 * Copyright 2023 Zemasterkrom (Raphaël KIMM)
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

class FileError extends Error {  
  constructor (message) {
    super(message)
    this.name = this.constructor.name
    Error.captureStackTrace(this, this.constructor);
  }
}

class IncorrectFileTypeError extends FileError {  
  constructor (message) {
    super(message)
    this.name = this.constructor.name
    Error.captureStackTrace(this, this.constructor);
  }
}

class FileWriteError extends FileError {  
  constructor (message) {
    super(message)
    this.name = this.constructor.name
    Error.captureStackTrace(this, this.constructor);
  }
}

class FileReadError extends FileError {  
  constructor (message) {
    super(message)
    this.name = this.constructor.name
    Error.captureStackTrace(this, this.constructor);
  }
}

/**
 * Utility class for creating environment files, similarly to Java with environment variables.
 *
 * In a dockerized or automated environment, this class may be of increased interest if a JavaScript application must
 * have access to environment variables when launching the application, which could be loaded from the environment file.
 *
 * Example : node FileEnvironmentConfigurator.js test.js utf-8 @JSKEY@ @JSVALUE@ "window['environment']['@JSKEY@'] = @JSVALUE@;" valueOne 0 valueTwo 1
 */
class FileEnvironmentConfigurator {
  /**
   * Configuration filename.
   */
  #environmentFilePath = null;

  /*
   * Environment file encoding.
   */
  #environmentFileEncoding = "utf8"

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
   * @param fp Environment file path
   * @param enc Environment file encoding. Default is utf8.
   * @param k Key placeholder
   * @param v Value placeholder
   * @param et Environment template
   * 
   * @throws {TypeError} Parameter can't be empty
   * @throws {FileError} File status does not allow writing
   */
  constructor(fp, enc, k, v, et) {
    if ((!fp && fp !== "") || (!k && k !== "") || (!v && v != "") || (!et && et !== "")) {
      throw new TypeError("Can't pass null objects")
    }

    if (/^\s*$/.test(fp)) {
      throw new TypeError("The environment file path can't be empty")
    }

    if (/^\s*$/.test(k)) {
      throw new TypeError("The key placeholder can't be empty")
    }

    if (/^\s*$/.test(v)) {
      throw new TypeError("The value placeholder can't be empty");
    }

    if (/^\s*$/.test(et)) {
      throw new TypeError("The environment template can't be empty");
    }

    if (fs.existsSync(fp)) {
      const stat = fs.statSync(fp);

      if (stat.isDirectory()) {
        throw new IncorrectFileTypeError(`File ${fp} is a directory`);
      } else if (!fs.constants.W_OK & stat.mode) {
        throw new FileWriteError(`Can't write to ${fp}`);
      }
    }

    this.#environmentFilePath = fp;
    this.#environmentFileEncoding = enc && /^.+$/.test(enc) ? enc : "utf8";
    this.#keyPlaceholder = k;
    this.#valuePlaceholder = v;
    this.#environmentTemplate = et;
  }

  /**
   * Define an environment variable in the environment file
   *
   * @param key Key currently being processed
   * @param value Value currently being processed
   * 
   * @throws {TypeError} Key can't be empty
   */
  setEnvironmentVariable(key, value) {
    if (this.#content.length !== 0) this.#content += "\n";

    if (!key || /^\s*$/.test(key)) {
      throw new TypeError(`Keys can't be empty. Concerned value : ${value}`)
    }

    this.#content += this.#environmentTemplate
      .replace(this.#keyPlaceholder, key)
      .replace(this.#valuePlaceholder, value);
  }

  /**
    * Save the created environment file.
    */
  async save() {
    await fs.promises.writeFile(this.#environmentFilePath, this.#content, {
      encoding: this.#environmentFileEncoding
    });
  }

  get filename() {
    return this.#environmentFilePath;
  }

  get environmentFileEncoding() {
    return this.#environmentFileEncoding;
  }

  get keyPlaceholder() {
    return this.#keyPlaceholder;
  }

  get valuePlaceholder() {
    return this.#valuePlaceholder;
  }

  get environmentTemplate() {
    return this.#environmentTemplate;
  }
}

async function main(args) {
  try {
    if (args.length < 6) {
      throw new TypeError('Usage: node FileEnvironmentConfigurator.js <Path to the environment file> <Environment file encoding> <Key placeholder> <Value placeholder> <Environment template> <First key> <First value> ...');
    }
  
    const ec = new FileEnvironmentConfigurator(args[0], args[1], args[2], args[3], args[4]);
  
    for (let i = 5; i < args.length; i += 2) {
      ec.setEnvironmentVariable(args[i], args[i + 1] ?? "");
    }
  
    await ec.save();
  } catch (e) {
    if (e.code === "EPERM" || e.code === "EBUSY" || e.code === "EACCES") {
      console.error(`Can't write to ${args[0]}`);
      process.exit(71);
    } else {
      console.error(e.message);
    }

    switch (e.constructor.name) {
      case "TypeError":
        process.exit(2);
      case "SystemError":
      case "IncorrectFileTypeError":
      case "FileWriteError":
      case "FileReadError":
        process.exit(71);
    }

    process.exit(1);
  }
}

main(process.argv.slice(2));