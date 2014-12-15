U2 = require 'uglify-js'
Profiles = require './profiles'

# PacGenerator is used like a singleton class instance.
# coffeelint: disable=missing_fat_arrows
module.exports =
  ascii: (str) ->
    str.replace /[\u0080-\uffff]/g, (char) ->
      hex = char.charCodeAt(0).toString(16)
      result = '\\u'
      result += '0' for _ in [hex.length...4]
      result += hex
      return result

  compress: (ast) ->
    ast.figure_out_scope()
    compressor = U2.Compressor(warnings: false, keep_fargs: true,
      if_return: false)
    compressed_ast = ast.transform(compressor)
    compressed_ast.figure_out_scope()
    compressed_ast.compute_char_frequency()
    compressed_ast.mangle_names()
    compressed_ast

  script: (options, profile, args) ->
    if typeof profile == 'string'
      profile = Profiles.byName(profile, options)
    refs = Profiles.allReferenceSet(profile, options,
      profileNotFound: args?.profileNotFound)

    profiles = new U2.AST_Object properties:
      for key, name of refs when key != '+direct'
        p = if typeof profile == 'object' and profile.name == name
          profile
        else
          Profiles.byName(name, options)
        if not p?
          p = Profiles.profileNotFound(name, args?.profileNotFound)
        new U2.AST_ObjectKeyVal(key: key, value: Profiles.compile(p))

    factory = new U2.AST_Function(
      argnames: [
        new U2.AST_SymbolFunarg name: 'init'
        new U2.AST_SymbolFunarg name: 'profiles'
      ]
      body: [new U2.AST_Return value: new U2.AST_Function(
        argnames: [
          new U2.AST_SymbolFunarg name: 'url'
          new U2.AST_SymbolFunarg name: 'host'
        ]
        body: [
          new U2.AST_Directive value: 'use strict'
          new U2.AST_Var definitions: [
            new U2.AST_VarDef name: new U2.AST_SymbolVar(name: 'result'), value:
              new U2.AST_SymbolRef name: 'init'
            new U2.AST_VarDef name: new U2.AST_SymbolVar(name: 'scheme'), value:
              new U2.AST_Call(
                expression: new U2.AST_Dot(
                  expression: new U2.AST_SymbolRef name: 'url'
                  property: 'substr'
                )
                args: [
                  new U2.AST_Number value: 0
                  new U2.AST_Call(
                    expression: new U2.AST_Dot(
                      expression: new U2.AST_SymbolRef name: 'url'
                      property: 'indexOf'
                    )
                    args: [new U2.AST_String value: ':']
                  )
                ]
              )
          ]
          new U2.AST_Do(
            body: new U2.AST_BlockStatement body: [
              new U2.AST_SimpleStatement body: new U2.AST_Assign(
                left: new U2.AST_SymbolRef name: 'result'
                operator: '='
                right: new U2.AST_Sub(
                  expression: new U2.AST_SymbolRef name: 'profiles'
                  property: new U2.AST_SymbolRef name: 'result'
                )
              )
              new U2.AST_If(
                condition: new U2.AST_Binary(
                  left: new U2.AST_UnaryPrefix(
                    operator: 'typeof'
                    expression: new U2.AST_SymbolRef name: 'result'
                  )
                  operator: '==='
                  right: new U2.AST_String value: 'function'
                )
                body: new U2.AST_SimpleStatement body: new U2.AST_Assign(
                  left: new U2.AST_SymbolRef name: 'result'
                  operator: '='
                  right: new U2.AST_Call(
                    expression: new U2.AST_SymbolRef name: 'result'
                    args: [
                      new U2.AST_SymbolRef name: 'url'
                      new U2.AST_SymbolRef name: 'host'
                      new U2.AST_SymbolRef name: 'scheme'
                    ]
                  )
                )
              )
            ]
            condition: new U2.AST_Binary(
              left: new U2.AST_Binary(
                left: new U2.AST_UnaryPrefix(
                  operator: 'typeof'
                  expression: new U2.AST_SymbolRef name: 'result'
                )
                operator: '!=='
                right: new U2.AST_String value: 'string'
              )
              operator: '||'
              right: new U2.AST_Binary(
                left: new U2.AST_Call(
                  expression: new U2.AST_Dot(
                    expression: new U2.AST_SymbolRef name: 'result'
                    property: 'charCodeAt'
                  )
                  args: [new U2.AST_Number(value: 0)]
                )
                operator: '==='
                right: new U2.AST_Number value: '+'.charCodeAt(0)
              )
            )
          )
          new U2.AST_Return value: new U2.AST_SymbolRef name: 'result'
        ]
      )]
    )
    new U2.AST_Toplevel body: [new U2.AST_Var definitions: [
      new U2.AST_VarDef(
        name: new U2.AST_SymbolVar name: 'FindProxyForURL'
        value: new U2.AST_Call(
          expression: factory
          args: [
            Profiles.profileResult profile.name
            profiles
          ]
        )
      )
    ]]
  # coffeelint: enable=missing_fat_arrows
