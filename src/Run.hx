using StringTools;

import as3hx.Writer;
import sys.FileSystem;
import sys.io.File;

class Run {
    
    static function errorString( e : as3hx.Parser.Error ) {
        return switch(e) {
        case EInvalidChar(c): "Invalid char '" + String.fromCharCode(c)+"' 0x"+StringTools.hex(c,2);
        case EUnexpected(src): "Unexpected " + src;
        case EUnterminatedString: "Unterminated string";
        case EUnterminatedComment: "Unterminated comment";
        case EUnterminatedXML: "Unterminated XML";
        }
    }
    
    static function loop( src: String, dst : String, excludes: List<String> ) {

        if (src == null) {
            Sys.println("source path cannot be null");
        }
        if (dst == null) {
            Sys.println("destination path cannot be null");
        }

        var subDirList : Array<String> = new Array<String>();

        var writer = new Writer(cfg);

        for( f in FileSystem.readDirectory(src) ) {

            var srcChildAbsPath : String = src + "/" + f;
            var dstChildAbsPath : String = dst + "/" + f;

            if ( FileSystem.isDirectory(srcChildAbsPath) ) {
                subDirList.push(f);
            }
            else 
            if( f.endsWith(".as") && !isExcludeFile(excludes, srcChildAbsPath) ) {
                var file = srcChildAbsPath;
                Sys.println("source AS3 file: " + file);
                var p = new as3hx.Parser(cfg);
                var content = sys.io.File.getContent(file);
                var program = try p.parseString(content,src,f) catch( e : as3hx.Parser.Error ) {
                    #if macro
                    sys.io.File.stderr().writeString(file+":"+p.line+": "+errorString(e)+"\n");
                    #end
                    if(cfg.errorContinue) {
                        errors.push("In " + file + "("+p.line+") : " + errorString(e));
                        continue;
                    }
                    else
                        neko.Lib.rethrow("In " + file + "("+p.line+") : " + errorString(e));
                }
                var out = dst;
                ensureDirectoryExists(out);
                var name = out + "/" + Writer.properCase(f.substr(0, -3),true) + ".hx";
                Sys.println("target HX file: " + name);
                var fw = File.write(name, false);
                warnings.set(name, writer.process(program, fw));
                fw.close();
            }
        }

        for (name in subDirList) {
            loop((src + "/" + name), (dst + "/" + name), excludes);
        }
    }

    static function isExcludeFile(excludes: List<String>, file: String) 
            return Lambda.filter(excludes, function (path) return as3hx.Config.toPath(file).indexOf(path.replace(".", "/")) > -1).length > 0;

    static var errors : Array<String> = new Array();
        static var warnings : Map<String,Map<String,Bool>> = new Map();
    static var cfg : as3hx.Config;
    public static function main() {
        cfg = new as3hx.Config();
        loop(cfg.src, cfg.dst, cfg.excludePaths);
        Sys.println("");
        Writer.showWarnings(warnings);
        Sys.println("");
        if(errors.length > 0) {
            Sys.println("ERRORS: These files were not written due to source parsing errors:");
            for(i in errors)
                Sys.println(i);
        }
    }

    static function ensureDirectoryExists(dir : String)
    {
        var tocreate = [];
        while (!FileSystem.exists(dir) && dir != '')
        {
            var parts = dir.split("/");
            tocreate.unshift(parts.pop());
            dir = parts.join("/");
        }
        for (part in tocreate)
        {
            if (part == '')
                continue;
            dir += "/" + part;
            try {
                FileSystem.createDirectory(dir);
            } catch (e : Dynamic) {
                throw "unable to create dir: " + dir;
            }
        }
    }
    
    static var reabs = ~/^([a-z]:|\\\\|\/)/i;
    public static function directory(dir : String, alt = ".")
    {
        if (null == dir)
            dir = alt;
        if( dir.endsWith("/") || dir.endsWith("\\") )
            dir = dir.substr(0, -1);
        if (!reabs.match(dir))
            dir = Sys.getCwd() + dir;
        dir = StringTools.replace(dir, "\\", "/");
        return dir;
    }
}