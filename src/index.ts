import { readFileSync, writeFileSync } from "fs";
import { getTRPCStructure, trpcStructureToSwiftClass } from "./generators/router.js";
import { indentSwiftCode, processTypeName } from "./utility.ts";
import { SwiftModelGenerationData, SwiftTRPCRouterDef, TRPCSwiftFlags } from "./types.ts";
import path from "path";
import { fileURLToPath } from "url";

// export { TRPCSwiftMeta } from "./extensions/trpc.ts";
export { extendZodWithSwift } from "./extensions/zod.ts";

export const trpcRouterToSwiftClient = (name: string, routerDef: SwiftTRPCRouterDef, flags: TRPCSwiftFlags): string => {
    const __filename = fileURLToPath(import.meta.url);
    const __dirname = path.dirname(__filename);

    const trpcStructure = getTRPCStructure(routerDef);
    const globalModels: SwiftModelGenerationData = {
        swiftCode: "",
        names: new Set<string>(),
    };
    const swiftClass = trpcStructureToSwiftClass(name, trpcStructure, {
        routeDepth: 0,
        globalModels,
        visibleModelNames: new Set<string>(),
        flags,
    });

    let swiftClient = readFileSync(path.join(__dirname, "../templates/TRPCClient.swift")).toString("utf-8");
    swiftClient += swiftClass;

    if (flags.createTypeAliases) {
        globalModels.names.forEach((modelName) => {
            if (flags.publicAccess) {
                swiftClient += "public ";
            }
            swiftClient += `typealias ${modelName} = ${processTypeName(name)}.${modelName}\n`;
        });
    }

    return indentSwiftCode(swiftClient);
};

export const trpcRouterToSwiftFile = (name: string, routerDef: SwiftTRPCRouterDef, flags: TRPCSwiftFlags, outFile: string) => {
    const generated = trpcRouterToSwiftClient(name, routerDef, flags);
    writeFileSync(outFile, generated);
};
