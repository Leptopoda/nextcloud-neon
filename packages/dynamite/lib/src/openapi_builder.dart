part of '../dynamite.dart';

class OpenAPIBuilder implements Builder {
  @override
  final buildExtensions = const {
    '.openapi.json': ['.openapi.dart'],
  };

  @override
  Future<void> build(final BuildStep buildStep) async {
    try {
      final inputId = buildStep.inputId;
      final outputId = inputId.changeExtension('.dart');

      final emitter = DartEmitter(
        orderDirectives: true,
        useNullSafetySyntax: true,
      );

      final spec = OpenAPI.fromJson(
        json.decode(
          await buildStep.readAsString(inputId),
        ) as Map<String, dynamic>,
      );
      final prefix = _toDartName(spec.info.title, uppercaseFirstCharacter: true);
      final supportedVersions = ['3.0.3', '3.1.0'];
      if (!supportedVersions.contains(spec.version)) {
        throw Exception('Only OpenAPI ${supportedVersions.join(', ')} are supported');
      }

      var tags = <String?>[
        null,
        if (spec.paths != null) ...{
          for (final pathItem in spec.paths!.values) ...{
            for (final operation in pathItem.operations.values) ...{
              if (operation.tags != null) ...{
                ...operation.tags!,
              },
            },
          },
        },
      ];
      for (final tag in tags.toList()) {
        final tagPart = tag?.split('/').first;
        if (!tags.contains(tagPart)) {
          tags.add(tagPart);
        }
      }
      tags = tags
        ..sort(
          (final a, final b) => a == null
              ? -1
              : b == null
                  ? 1
                  : a.compareTo(b),
        );

      final hasAnySecurity = spec.security?.isNotEmpty ?? false;

      final state = State(prefix);
      final output = <String>[
        "import 'dart:convert';",
        "import 'dart:io';",
        "import 'dart:typed_data';",
        '',
        "import 'package:built_collection/built_collection.dart';",
        "import 'package:built_value/built_value.dart';",
        "import 'package:built_value/json_object.dart';",
        "import 'package:built_value/serializer.dart';",
        "import 'package:built_value/standard_json_plugin.dart';",
        "import 'package:cookie_jar/cookie_jar.dart';",
        '',
        "export 'package:cookie_jar/cookie_jar.dart';",
        '',
        "part '${p.basename(outputId.changeExtension('.g.dart').path)}';",
        '',
        Extension(
          (final b) => b
            ..name = '${prefix}HttpClientResponseBody'
            ..on = refer('HttpClientResponse')
            ..methods.addAll([
              Method(
                (final b) => b
                  ..name = 'bodyBytes'
                  ..returns = refer('Future<Uint8List>')
                  ..type = MethodType.getter
                  ..modifier = MethodModifier.async
                  ..body = const Code(
                    '''
                  final chunks = await toList();
                  if (chunks.isEmpty) {
                    return Uint8List(0);
                  }
                  return Uint8List.fromList(chunks.reduce((final value, final element) => [...value, ...element]));
                    ''',
                  ),
              ),
              Method(
                (final b) => b
                  ..name = 'body'
                  ..returns = refer('Future<String>')
                  ..type = MethodType.getter
                  ..modifier = MethodModifier.async
                  ..lambda = true
                  ..body = const Code(
                    'utf8.decode(await bodyBytes)',
                  ),
              ),
            ]),
        ).accept(emitter).toString(),
        Class(
          (final b) => b
            ..name = '${prefix}Response'
            ..types.addAll([
              refer('T'),
              refer('U'),
            ])
            ..fields.addAll([
              Field(
                (final b) => b
                  ..name = 'data'
                  ..type = refer('T')
                  ..modifier = FieldModifier.final$,
              ),
              Field(
                (final b) => b
                  ..name = 'headers'
                  ..type = refer('U')
                  ..modifier = FieldModifier.final$,
              ),
            ])
            ..constructors.add(
              Constructor(
                (final b) => b
                  ..requiredParameters.addAll(
                    ['data', 'headers'].map(
                      (final name) => Parameter(
                        (final b) => b
                          ..name = name
                          ..toThis = true,
                      ),
                    ),
                  ),
              ),
            )
            ..methods.add(
              Method(
                (final b) => b
                  ..name = 'toString'
                  ..returns = refer('String')
                  ..annotations.add(refer('override'))
                  ..lambda = true
                  ..body = Code(
                    "'${prefix}Response(data: \$data, headers: \$headers)'",
                  ),
              ),
            ),
        ).accept(emitter).toString(),
        Class(
          (final b) => b
            ..name = '_Response'
            ..fields.addAll([
              Field(
                (final b) => b
                  ..name = 'statusCode'
                  ..type = refer('int')
                  ..modifier = FieldModifier.final$,
              ),
              Field(
                (final b) => b
                  ..name = 'headers'
                  ..type = refer('Map<String, String>')
                  ..modifier = FieldModifier.final$,
              ),
              Field(
                (final b) => b
                  ..name = 'body'
                  ..type = refer('Uint8List')
                  ..modifier = FieldModifier.final$,
              ),
            ])
            ..constructors.add(
              Constructor(
                (final b) => b
                  ..requiredParameters.addAll(
                    ['statusCode', 'headers', 'body'].map(
                      (final name) => Parameter(
                        (final b) => b
                          ..name = name
                          ..toThis = true,
                      ),
                    ),
                  ),
              ),
            )
            ..methods.add(
              Method(
                (final b) => b
                  ..name = 'toString'
                  ..returns = refer('String')
                  ..annotations.add(refer('override'))
                  ..lambda = true
                  ..body = const Code(
                    r"'_Response(statusCode: $statusCode, headers: $headers, body: ${utf8.decode(body)})'",
                  ),
              ),
            ),
        ).accept(emitter).toString(),
        Class(
          (final b) => b
            ..name = '${prefix}ApiException'
            ..extend = refer('_Response')
            ..implements.add(refer('Exception'))
            ..constructors.addAll(
              [
                Constructor(
                  (final b) => b
                    ..requiredParameters.addAll(
                      ['statusCode', 'headers', 'body'].map(
                        (final name) => Parameter(
                          (final b) => b
                            ..name = name
                            ..toSuper = true,
                        ),
                      ),
                    ),
                ),
                Constructor(
                  (final b) => b
                    ..name = 'fromResponse'
                    ..factory = true
                    ..lambda = true
                    ..requiredParameters.add(
                      Parameter(
                        (final b) => b
                          ..name = 'response'
                          ..type = refer('_Response'),
                      ),
                    )
                    ..body = Code('${prefix}ApiException(response.statusCode, response.headers, response.body,)'),
                ),
              ],
            )
            ..methods.add(
              Method(
                (final b) => b
                  ..name = 'toString'
                  ..returns = refer('String')
                  ..annotations.add(refer('override'))
                  ..lambda = true
                  ..body = Code(
                    "'${prefix}ApiException(statusCode: \${super.statusCode}, headers: \${super.headers}, body: \${utf8.decode(super.body)})'",
                  ),
              ),
            ),
        ).accept(emitter).toString(),
        if (hasAnySecurity) ...[
          Class(
            (final b) => b
              ..name = '${prefix}Authentication'
              ..abstract = true
              ..methods.add(
                Method(
                  (final b) => b
                    ..name = 'headers'
                    ..type = MethodType.getter
                    ..returns = refer('Map<String, String>'),
                ),
              ),
          ).accept(emitter).toString(),
        ],
      ];

      if (spec.security != null) {
        for (final securityRequirement in spec.security!) {
          for (final name in securityRequirement.keys) {
            final securityScheme = spec.components!.securitySchemes![name]!;
            switch (securityScheme.type) {
              case 'http':
                switch (securityScheme.scheme) {
                  case 'basic':
                    output.add(
                      Class(
                        (final b) {
                          final fields = ['username', 'password'];
                          b
                            ..name = '${prefix}HttpBasicAuthentication'
                            ..extend = refer('${prefix}Authentication')
                            ..constructors.add(
                              Constructor(
                                (final b) => b
                                  ..optionalParameters.addAll(
                                    fields.map(
                                      (final name) => Parameter(
                                        (final b) => b
                                          ..name = name
                                          ..toThis = true
                                          ..named = true
                                          ..required = true,
                                      ),
                                    ),
                                  ),
                              ),
                            )
                            ..fields.addAll(
                              fields.map(
                                (final name) => Field(
                                  (final b) => b
                                    ..name = name
                                    ..type = refer('String')
                                    ..modifier = FieldModifier.final$,
                                ),
                              ),
                            )
                            ..methods.add(
                              Method(
                                (final b) => b
                                  ..name = 'headers'
                                  ..type = MethodType.getter
                                  ..returns = refer('Map<String, String>')
                                  ..lambda = true
                                  ..body = const Code(r'''
                                    {
                                      'Authorization': 'Basic ${base64.encode(utf8.encode('$username:$password'))}',
                                    }
                                  '''),
                              ),
                            );
                        },
                      ).accept(emitter).toString(),
                    );
                    continue;
                }
            }
            throw Exception('Can not work with security scheme ${securityScheme.toJson()}');
          }
        }
      }

      for (final tag in tags) {
        final isRootClient = tag == null;
        final paths = <String, PathItem>{};

        if (spec.paths != null) {
          for (final path in spec.paths!.keys) {
            final pathItem = spec.paths![path]!;
            for (final method in pathItem.operations.keys) {
              final operation = pathItem.operations[method]!;
              if ((tag != null && operation.tags != null && operation.tags!.contains(tag)) ||
                  (tag == null && (operation.tags == null || operation.tags!.isEmpty))) {
                if (paths[path] == null) {
                  paths[path] = PathItem(
                    description: pathItem.description,
                    parameters: pathItem.parameters,
                  );
                }
                paths[path] = paths[path]!.copyWithOperations({method: operation});
              }
            }
          }
        }

        output.add(
          Class(
            (final b) {
              if (isRootClient) {
                b
                  ..fields.addAll([
                    Field(
                      (final b) => b
                        ..name = 'baseURL'
                        ..type = refer('String')
                        ..modifier = FieldModifier.final$,
                    ),
                    Field(
                      (final b) => b
                        ..name = 'baseHeaders'
                        ..type = refer('Map<String, String>')
                        ..modifier = FieldModifier.final$
                        ..late = true,
                    ),
                    Field(
                      (final b) => b
                        ..name = 'httpClient'
                        ..type = refer('HttpClient')
                        ..modifier = FieldModifier.final$
                        ..late = true,
                    ),
                    Field(
                      (final b) => b
                        ..name = 'cookieJar'
                        ..type = refer('CookieJar?')
                        ..modifier = FieldModifier.final$,
                    ),
                    if (hasAnySecurity) ...[
                      Field(
                        (final b) => b
                          ..name = 'authentication'
                          ..type = refer('${prefix}Authentication?')
                          ..modifier = FieldModifier.final$,
                      ),
                    ],
                  ])
                  ..constructors.add(
                    Constructor(
                      (final b) => b
                        ..requiredParameters.add(
                          Parameter(
                            (final b) => b
                              ..name = 'baseURL'
                              ..toThis = true,
                          ),
                        )
                        ..optionalParameters.addAll([
                          Parameter(
                            (final b) => b
                              ..name = 'baseHeaders'
                              ..type = refer('Map<String, String>?')
                              ..named = true,
                          ),
                          Parameter(
                            (final b) => b
                              ..name = 'userAgent'
                              ..type = refer('String?')
                              ..named = true,
                          ),
                          Parameter(
                            (final b) => b
                              ..name = 'httpClient'
                              ..type = refer('HttpClient?')
                              ..named = true,
                          ),
                          Parameter(
                            (final b) => b
                              ..name = 'cookieJar'
                              ..toThis = true
                              ..named = true,
                          ),
                          if (hasAnySecurity) ...[
                            Parameter(
                              (final b) => b
                                ..name = 'authentication'
                                ..toThis = true
                                ..named = true,
                            ),
                          ],
                        ])
                        ..body = Code('''
                        this.baseHeaders = {
                          if (baseHeaders != null) ...{
                            ...baseHeaders,
                          },
                        ${hasAnySecurity ? '''
                          if (authentication != null) ...{
                            ...authentication!.headers,
                          },
                        ''' : ''}
                        };
                        this.httpClient = (httpClient ?? HttpClient())..userAgent = userAgent;
                      '''),
                    ),
                  )
                  ..methods.addAll([
                    Method(
                      (final b) => b
                        ..name = 'doRequest'
                        ..returns = refer('Future<_Response>')
                        ..modifier = MethodModifier.async
                        ..requiredParameters.addAll([
                          Parameter(
                            (final b) => b
                              ..name = 'method'
                              ..type = refer('String'),
                          ),
                          Parameter(
                            (final b) => b
                              ..name = 'path'
                              ..type = refer('String'),
                          ),
                          Parameter(
                            (final b) => b
                              ..name = 'headers'
                              ..type = refer('Map<String, String>'),
                          ),
                          Parameter(
                            (final b) => b
                              ..name = 'body'
                              ..type = refer('Uint8List?'),
                          ),
                        ])
                        ..body = const Code(r'''
                        final uri = Uri.parse('$baseURL$path');
                        final request = await httpClient.openUrl(method, uri);
                        for (final header in {...baseHeaders, ...headers}.entries) {
                          request.headers.add(header.key, header.value);
                        }
                        if (body != null) {
                          request.add(body.toList());
                        }
                        if (cookieJar != null) {
                          request.cookies.addAll(await cookieJar!.loadForRequest(uri));
                        }

                        final response = await request.close();
                        if (cookieJar != null) {
                          await cookieJar!.saveFromResponse(uri, response.cookies);
                        }
                        final responseHeaders = <String, String>{};
                        response.headers.forEach((final name, final values) {
                          responseHeaders[name] = values.last;
                        });
                        return _Response(
                          response.statusCode,
                          responseHeaders,
                          await response.bodyBytes,
                        );
                      '''),
                    ),
                  ]);
              } else {
                b
                  ..fields.add(
                    Field(
                      (final b) => b
                        ..name = 'rootClient'
                        ..type = refer('${prefix}Client')
                        ..modifier = FieldModifier.final$,
                    ),
                  )
                  ..constructors.add(
                    Constructor(
                      (final b) => b.requiredParameters.add(
                        Parameter(
                          (final b) => b
                            ..name = 'rootClient'
                            ..toThis = true,
                        ),
                      ),
                    ),
                  );
              }
              final matchedTags = spec.tags?.where((final t) => t.name == tag).toList();
              b
                ..name = '$prefix${isRootClient ? 'Client' : _clientName(tag)}'
                ..docs.addAll(
                  _descriptionToDocs(
                    matchedTags != null && matchedTags.isNotEmpty ? matchedTags.single.description : null,
                  ),
                )
                ..methods.addAll(
                  [
                    for (final t in tags
                        .whereType<String>()
                        .where(
                          (final t) => (tag != null && (t.startsWith('$tag/'))) || (tag == null && !t.contains('/')),
                        )
                        .toList()) ...[
                      Method(
                        (final b) => b
                          ..name = _toDartName(tag == null ? t : t.substring('$tag/'.length))
                          ..lambda = true
                          ..type = MethodType.getter
                          ..returns = refer('$prefix${_clientName(t)}')
                          ..body = Code('$prefix${_clientName(t)}(${isRootClient ? 'this' : 'rootClient'})'),
                      ),
                    ],
                    for (final path in paths.keys) ...[
                      for (final httpMethod in paths[path]!.operations.keys) ...[
                        Method(
                          (final b) {
                            final operation = paths[path]!.operations[httpMethod]!;
                            final operationId = operation.operationId ?? _toDartName('$httpMethod-$path');
                            final pathParameters = <spec_parameter.Parameter>[
                              if (paths[path]!.parameters != null) ...paths[path]!.parameters!,
                            ];
                            final parameters = <spec_parameter.Parameter>[
                              ...pathParameters,
                              if (operation.parameters != null) ...operation.parameters!,
                            ];
                            b
                              ..name = _toDartName(_filterMethodName(operationId, tag ?? ''))
                              ..modifier = MethodModifier.async
                              ..docs.addAll([
                                ..._descriptionToDocs(operation.summary),
                                if (operation.summary != null && operation.description != null) ...[
                                  '',
                                ],
                                ..._descriptionToDocs(operation.description),
                              ]);

                            final code = StringBuffer('''
                            var path = '$path';
                            final queryParameters = <String, dynamic>{};
                            final headers = <String, String>{};
                            Uint8List? body;
                          ''');

                            for (final parameter in parameters) {
                              final nullable = _isParameterNullable(
                                parameter.required,
                                parameter.schema?.default_,
                              );

                              final result = resolveType(
                                spec,
                                state,
                                _toDartName(
                                  parameter.name,
                                  uppercaseFirstCharacter: true,
                                ),
                                parameter.schema!,
                              );

                              if (result.name == 'String') {
                                if (parameter.schema?.pattern != null) {
                                  code.write('''
                                  if (!RegExp(r'${parameter.schema!.pattern!}').hasMatch(${_toDartName(parameter.name)})) {
                                    throw Exception('Invalid value "\$${_toDartName(parameter.name)}" for parameter "${_toDartName(parameter.name)}" with pattern "' r'${parameter.schema!.pattern!}"'); // coverage:ignore-line
                                  }
                                  ''');
                                }
                                if (parameter.schema?.minLength != null) {
                                  code.write('''
                                  if (${_toDartName(parameter.name)}.length < ${parameter.schema!.minLength!}) {
                                    throw Exception('Parameter "${_toDartName(parameter.name)}" has to be at least ${parameter.schema!.minLength!} characters long'); // coverage:ignore-line
                                  }
                                  ''');
                                }
                                if (parameter.schema?.maxLength != null) {
                                  code.write('''
                                  if (${_toDartName(parameter.name)}.length > ${parameter.schema!.maxLength!}) {
                                    throw Exception('Parameter "${_toDartName(parameter.name)}" has to be at most ${parameter.schema!.maxLength!} characters long'); // coverage:ignore-line
                                  }
                                  ''');
                                }
                              }

                              final defaultValueCode = parameter.schema?.default_ != null
                                  ? _valueToEscapedValue(result.name, parameter.schema!.default_!.toString())
                                  : null;

                              b.optionalParameters.add(
                                Parameter(
                                  (final b) {
                                    b
                                      ..named = true
                                      ..name = _toDartName(parameter.name)
                                      ..required = (parameter.required ?? false) && defaultValueCode == null;
                                    if (parameter.schema != null) {
                                      b.type = refer(
                                        _makeNullable(
                                          result.name,
                                          nullable,
                                        ),
                                      );
                                    }
                                    if (defaultValueCode != null) {
                                      b.defaultTo = Code(defaultValueCode);
                                    }
                                  },
                                ),
                              );

                              if (nullable) {
                                code.write('if (${_toDartName(parameter.name)} != null) {');
                              }
                              final isPlainList = result is TypeResultBuiltList && !result.fromContentString;
                              final value = result.encode(
                                result.serialize(_toDartName(parameter.name)),
                                onlyChildren: isPlainList && parameter.in_ == 'query',
                                // Objects inside the query always have to be interpreted in some way
                                mimeType: 'application/json',
                              );
                              if (defaultValueCode != null && parameter.in_ != 'path') {
                                code.write('if (${_toDartName(parameter.name)} != $defaultValueCode) {');
                              }
                              switch (parameter.in_) {
                                case 'path':
                                  code.write(
                                    "path = path.replaceAll('{${parameter.name}}', Uri.encodeQueryComponent($value));",
                                  );
                                  break;
                                case 'query':
                                  code.write(
                                    "queryParameters['${parameter.name}${isPlainList ? '[]' : ''}'] = $value;",
                                  );
                                  break;
                                case 'header':
                                  code.write(
                                    "headers['${parameter.name}'] = $value;",
                                  );
                                  break;
                                default:
                                  throw Exception('Can not work with parameter in "${parameter.in_}"');
                              }
                              if (defaultValueCode != null) {
                                code.write('}');
                              }
                              if (nullable) {
                                code.write('}');
                              }
                            }

                            if (operation.requestBody != null) {
                              if (operation.requestBody!.content!.length > 1) {
                                throw Exception('Can not work with multiple mime types right now');
                              }
                              for (final mimeType in operation.requestBody!.content!.keys) {
                                final mediaType = operation.requestBody!.content![mimeType]!;

                                code.write("headers['Content-Type'] = '$mimeType';");

                                final result = resolveType(
                                  spec,
                                  state,
                                  _toDartName('$operationId-request-$mimeType', uppercaseFirstCharacter: true),
                                  mediaType.schema!,
                                );
                                final parameterName = _toDartName(result.name.replaceFirst(prefix, ''));
                                switch (mimeType) {
                                  case 'application/json':
                                  case 'application/x-www-form-urlencoded':
                                    final nullable = _isParameterNullable(
                                      operation.requestBody!.required,
                                      mediaType.schema?.default_,
                                    );
                                    b.optionalParameters.add(
                                      Parameter(
                                        (final b) => b
                                          ..name = parameterName
                                          ..type = refer(_makeNullable(result.name, nullable))
                                          ..named = true
                                          ..required = operation.requestBody!.required ?? false,
                                      ),
                                    );

                                    if (nullable) {
                                      code.write('if ($parameterName != null) {');
                                    }
                                    code.write(
                                      'body = Uint8List.fromList(utf8.encode(${result.encode(result.serialize(parameterName), mimeType: mimeType)}));',
                                    );
                                    if (nullable) {
                                      code.write('}');
                                    }
                                    break;
                                  default:
                                    throw Exception('Can not parse mime type "$mimeType"');
                                }
                              }
                            }

                            code.write(
                              '''
                            final response = await ${isRootClient ? '' : 'rootClient.'}doRequest(
                              '$httpMethod',
                              Uri(path: path, queryParameters: queryParameters.isNotEmpty ? queryParameters : null).toString(),
                              headers,
                              body,
                            );
                          ''',
                            );

                            if (operation.responses != null) {
                              if (operation.responses!.length > 1) {
                                throw Exception('Can not work with multiple status codes right now');
                              }
                              for (final statusCode in operation.responses!.keys) {
                                final response = operation.responses![statusCode]!;
                                code.write('if (response.statusCode == $statusCode) {');

                                String? headersType;
                                String? headersValue;
                                if (response.headers != null) {
                                  final identifier =
                                      '${tag != null ? _toDartName(tag, uppercaseFirstCharacter: true) : null}${_toDartName(operationId, uppercaseFirstCharacter: true)}Headers';
                                  final headerParseFunctions = <String, String>{};
                                  for (final headerName in response.headers!.keys) {
                                    final functionIdentifier = '_${_toDartName('${identifier}Parse$headerName')}';
                                    headerParseFunctions[headerName] = functionIdentifier;
                                    final result = resolveType(
                                      spec,
                                      state,
                                      identifier,
                                      response.headers![headerName]!.schema!,
                                    );
                                    output.add(
                                      '${result.name} $functionIdentifier(final Map data, final String key) => ${result.deserialize(result.decode('data[key]'))};',
                                    );
                                  }
                                  final result = resolveType(
                                    spec,
                                    state,
                                    identifier,
                                    Schema(
                                      type: 'object',
                                      properties: {
                                        for (final headerName in response.headers!.keys) ...{
                                          headerName.toLowerCase(): response.headers![headerName]!.schema!,
                                        },
                                      },
                                    ),
                                    // extraJsonSerializableValues: {
                                    //   'disallowUnrecognizedKeys': 'false',
                                    // },
                                    extraJsonKeyValues: {
                                      for (final headerName in response.headers!.keys) ...{
                                        headerName.toLowerCase(): {
                                          'readValue': headerParseFunctions[headerName]!,
                                        },
                                      },
                                    },
                                  );
                                  headersType = result.name;
                                  headersValue = result.deserialize('response.headers');
                                }

                                String? dataType;
                                String? dataValue;
                                if (response.content != null) {
                                  if (response.content!.length > 1) {
                                    throw Exception('Can not work with multiple mime types right now');
                                  }
                                  for (final mimeType in response.content!.keys) {
                                    final mediaType = response.content![mimeType]!;

                                    final result = resolveType(
                                      spec,
                                      state,
                                      _toDartName(
                                        '$operationId-response-$statusCode-$mimeType',
                                        uppercaseFirstCharacter: true,
                                      ),
                                      mediaType.schema!,
                                    );
                                    if (mimeType == '*/*' || mimeType.startsWith('image/')) {
                                      dataType = 'Uint8List';
                                      dataValue = 'response.body';
                                    } else if (mimeType.startsWith('text/')) {
                                      dataType = 'String';
                                      dataValue = 'utf8.decode(response.body)';
                                    } else if (mimeType == 'application/json') {
                                      dataType = result.name;
                                      if (result.name == 'dynamic') {
                                        dataValue = '';
                                      } else {
                                        dataValue = result.deserialize(result.decode('utf8.decode(response.body)'));
                                      }
                                    } else {
                                      throw Exception('Can not parse mime type "$mimeType"');
                                    }
                                  }
                                }

                                if (headersType != null && dataType != null) {
                                  b.returns = refer('Future<${prefix}Response<$dataType, $headersType>>');
                                  code.write(
                                    'return ${prefix}Response<$dataType, $headersType>($dataValue, $headersValue,);',
                                  );
                                } else if (headersType != null) {
                                  b.returns = refer('Future<$headersType>');
                                  code.write('return $headersValue;');
                                } else if (dataType != null) {
                                  b.returns = refer('Future<$dataType>');
                                  code.write('return $dataValue;');
                                } else {
                                  b.returns = refer('Future');
                                  code.write('return;');
                                }

                                code.write('}');
                              }
                              code.write(
                                'throw ${prefix}ApiException.fromResponse(response); // coverage:ignore-line\n',
                              );
                            } else {
                              b.returns = refer('Future');
                            }
                            b.body = Code(code.toString());
                          },
                        ),
                      ],
                    ],
                  ],
                );
            },
          ).accept(emitter).toString(),
        );
      }

      if (spec.components?.schemas != null) {
        for (final name in spec.components!.schemas!.keys) {
          final schema = spec.components!.schemas![name]!;

          final identifier = _toDartName(name, uppercaseFirstCharacter: true);
          if (schema.type == null && schema.ref == null && schema.ofs == null) {
            output.add('typedef $identifier = dynamic;');
          } else {
            final result = resolveType(
              spec,
              state,
              identifier,
              schema,
            );
            if (result is TypeResultBase) {
              output.add('typedef $identifier = ${result.name};');
            }
          }
        }
      }

      output.addAll(state.output.map((final e) => e.accept(emitter).toString()));

      if (state.registeredJsonObjects.isNotEmpty) {
        output.addAll([
          '@SerializersFor(const [',
          for (final name in state.registeredJsonObjects) ...[
            '$name,',
          ],
          '])',
          r'final Serializers serializers = (_$serializers.toBuilder()..addPlugin(StandardJsonPlugin())).build();',
          '',
          '// coverage:ignore-start',
          'T deserialize$prefix<T>(final Object data) => serializers.deserialize(data, specifiedType: FullType(T))! as T;',
          '',
          'Object? serialize$prefix<T>(final T data) => serializers.serialize(data, specifiedType: FullType(T));',
          '// coverage:ignore-end',
        ]);
      }

      final formatter = DartFormatter(
        pageWidth: 120,
      );
      const coverageIgnoreStart = '  // coverage:ignore-start';
      const coverageIgnoreEnd = '  // coverage:ignore-end';
      final patterns = [
        RegExp(
          r'factory .*\.fromJson\(Map<String, dynamic> json\) => _\$.*FromJson\(json\);',
        ),
        RegExp(
          r'Map<String, dynamic> toJson\(\) => _\$.*ToJson\(this\);',
        ),
        RegExp(
          r'factory .*\.fromJsonString\(String data\) => .*\.fromJson\(json\.decode\(data\)(?: as Map<String, dynamic>)?\);',
        ),
        RegExp(
          r'static String toJsonString\(.* data\) => json\.encode\(data(?:\.toJson\(\))?\);',
        ),
        RegExp(
          r'dynamic toJson\(\) => _data;',
        ),
      ];
      var outputString = output.join('\n');
      for (final pattern in patterns) {
        outputString = outputString.replaceAllMapped(
          pattern,
          (final match) => '$coverageIgnoreStart\n${match.group(0)}\n$coverageIgnoreEnd',
        );
      }
      await buildStep.writeAsString(
        outputId,
        formatter.format(outputString),
      );
    } catch (e, s) {
      print(s);

      rethrow;
    }
  }
}

String _clientName(final String tag) => '${_toDartName(tag, uppercaseFirstCharacter: true)}Client';

String _toDartName(
  final String input, {
  final bool uppercaseFirstCharacter = false,
}) {
  final result = StringBuffer();

  final parts = input.split('');
  for (var i = 0; i < parts.length; i++) {
    var char = parts[i];
    final prevChar = i > 0 ? parts[i - 1] : null;
    if (_isNonAlphaNumericString(char)) {
      continue;
    }
    if (prevChar != null && _isNonAlphaNumericString(prevChar)) {
      char = char.toUpperCase();
    }
    if (i == 0) {
      if (uppercaseFirstCharacter) {
        char = char.toUpperCase();
      } else {
        char = char.toLowerCase();
      }
    }
    result.write(char);
  }

  final out = result.toString();
  if (_dartKeywords.contains(out) || RegExp(r'^[0-9]+$', multiLine: true).hasMatch(out)) {
    return '\$$out';
  }

  return out;
}

final _dartKeywords = [
  'assert',
  'break',
  'case',
  'catch',
  'class',
  'const',
  'continue',
  'default',
  'do',
  'else',
  'enum',
  'extends',
  'false',
  'final',
  'finally',
  'for',
  'if',
  'in',
  'is',
  'new',
  'null',
  'rethrow',
  'return',
  'super',
  'switch',
  'this',
  'throw',
  'true',
  'try',
  'var',
  'void',
  'while',
  'with',
  'async',
  'hide',
  'on',
  'show',
  'sync',
  'abstract',
  'as',
  'covariant',
  'deferred',
  'dynamic',
  'export',
  'extension',
  'external',
  'factory',
  'function',
  'get',
  'implements',
  'import',
  'interface',
  'library',
  'mixin',
  'operator',
  'part',
  'set',
  'static',
  'typedef',
];

bool _isNonAlphaNumericString(final String input) => !RegExp(r'^[a-zA-Z0-9]$').hasMatch(input);

String _makeNullable(final String type, final bool nullable) => nullable && type != 'dynamic' ? '$type?' : type;

String _toFieldName(final String dartName, final String type) => dartName == type ? '\$$dartName' : dartName;

bool _isParameterNullable(final bool? required, final dynamic default_) => !(required ?? false) && default_ == null;

String _valueToEscapedValue(final String type, final dynamic value) => type == 'String' ? "'$value'" : value.toString();

String _toCamelCase(final String name) {
  var result = '';
  var upperCase = false;
  var firstCharacter = true;
  for (final char in name.split('')) {
    if (char == '_') {
      upperCase = true;
    } else if (char == r'$') {
      result += r'$';
    } else {
      result += firstCharacter ? char.toLowerCase() : (upperCase ? char.toUpperCase() : char);
      upperCase = false;
      firstCharacter = false;
    }
  }
  return result;
}

List<String> _descriptionToDocs(final String? description) => [
      if (description != null && description.isNotEmpty) ...[
        for (final line in description.split('\n')) ...[
          '/// $line',
        ],
      ],
    ];

String _filterMethodName(final String operationId, final String tag) {
  final expandedTag = tag.split('/').toList();
  final parts = operationId.split('-');
  final output = <String>[];
  for (var i = 0; i < parts.length; i++) {
    if (expandedTag.length <= i || expandedTag[i] != parts[i]) {
      output.add(parts[i]);
    }
  }
  return output.join('-');
}

class State {
  State(this.prefix);

  final String prefix;
  final resolvedTypes = <String>[];
  final registeredJsonObjects = <String>[];
  final output = <Spec>[];
}

TypeResult resolveObject(
  final OpenAPI spec,
  final State state,
  final String identifier,
  final Schema schema, {
  required final Map<String, Map<String, String>>? extraJsonKeyValues,
  final bool fromContentString = false,
}) {
  if (!state.resolvedTypes.contains('${state.prefix}$identifier')) {
    state.resolvedTypes.add('${state.prefix}$identifier');
    state.registeredJsonObjects.add('${state.prefix}$identifier');
    state.output.add(
      Class(
        (final b) {
          b
            ..name = '${state.prefix}$identifier'
            ..docs.addAll(_descriptionToDocs(schema.description))
            ..abstract = true
            ..implements.add(
              refer(
                'Built<${state.prefix}$identifier, ${state.prefix}${identifier}Builder>',
              ),
            )
            ..constructors.addAll(
              [
                Constructor(
                  (final b) => b
                    ..name = '_'
                    ..constant = true,
                ),
                Constructor(
                  (final b) => b
                    ..factory = true
                    ..lambda = true
                    ..optionalParameters.add(
                      Parameter(
                        (final b) => b
                          ..name = 'b'
                          ..type = refer('void Function(${state.prefix}${identifier}Builder)?'),
                      ),
                    )
                    ..redirect = refer('_\$${state.prefix}$identifier'),
                ),
              ],
            )
            ..methods.addAll([
              for (final propertyName in schema.properties!.keys) ...[
                Method(
                  (final b) {
                    final propertySchema = schema.properties![propertyName]!;
                    final result = resolveType(
                      spec,
                      state,
                      '${identifier}_${_toDartName(propertyName, uppercaseFirstCharacter: true)}',
                      propertySchema,
                    );

                    b
                      ..name = _toDartName(propertyName)
                      ..returns = refer(
                        _makeNullable(
                          result.name,
                          !(schema.required ?? []).contains(propertyName),
                        ),
                      )
                      ..type = MethodType.getter
                      ..docs.addAll(_descriptionToDocs(propertySchema.description));
                    final hasDifferentName = _toDartName(propertyName) != propertyName;
                    final isContentString = propertySchema.isContentString;
                    final isContentStringArray = isContentString && result is TypeResultBuiltList;
                    final hasExtraJsonKeyValues =
                        extraJsonKeyValues != null && extraJsonKeyValues.containsKey(propertyName);
                    if (hasDifferentName || isContentString || isContentStringArray || hasExtraJsonKeyValues) {
                      var fromJson = '${result.name}.fromJsonString';
                      var toJson = '${result.name}.toJsonString';
                      if (isContentStringArray) {
                        fromJson = '_${_toDartName('${state.prefix}${identifier}FromJsonString')}';
                        if (!state.resolvedTypes.contains(fromJson)) {
                          state.resolvedTypes.add(fromJson);
                          state.output.add(
                            Method(
                              (final b) => b
                                ..name = fromJson
                                ..returns = refer(result.name)
                                ..lambda = true
                                ..requiredParameters.addAll([
                                  Parameter(
                                    (final b) => b
                                      ..name = 'data'
                                      ..type = refer('String'),
                                  ),
                                ])
                                ..body = Code('${result.deserialize(result.decode('data'))};'),
                            ),
                          );
                        }
                        toJson = '_${_toDartName('${state.prefix}${identifier}ToJsonString')}';
                        if (!state.resolvedTypes.contains(toJson)) {
                          state.resolvedTypes.add(toJson);
                          state.output.add(
                            Method(
                              (final b) => b
                                ..name = toJson
                                ..returns = refer('String?')
                                ..lambda = true
                                ..requiredParameters.addAll([
                                  Parameter(
                                    (final b) => b
                                      ..name = 'data'
                                      ..type = refer(_makeNullable(result.name, true)),
                                  ),
                                ])
                                ..body = Code(
                                  'data == null ? null : ${result.encode(result.serialize('data'), mimeType: 'application/json')};',
                                ),
                            ),
                          );
                        }
                      }

                      b.annotations.add(
                        refer('BuiltValueField').call(
                          [],
                          {
                            if (hasDifferentName) ...{
                              'wireName': refer("'$propertyName'"),
                            },
                            if (isContentString || isContentStringArray) ...{
                              'fromJson': refer(fromJson),
                              'toJson': refer(toJson),
                            },
                            if (hasExtraJsonKeyValues) ...{
                              for (final key in extraJsonKeyValues[propertyName]!.keys) ...{
                                key: refer(extraJsonKeyValues[propertyName]![key]!),
                              },
                            },
                          },
                        ),
                      );
                    }
                  },
                ),
              ],
              Method((final b) {
                b
                  ..name = '_defaults'
                  ..returns = refer('void')
                  ..static = true
                  ..lambda = true
                  ..annotations.add(
                    refer('BuiltValueHook').call(
                      [],
                      {
                        'initializeBuilder': refer('true'),
                      },
                    ),
                  )
                  ..requiredParameters.add(
                    Parameter(
                      (final b) => b
                        ..name = 'b'
                        ..type = refer('${state.prefix}${identifier}Builder'),
                    ),
                  );
                final defaults = <String>[];
                for (final propertyName in schema.properties!.keys) {
                  final propertySchema = schema.properties![propertyName]!;
                  if (propertySchema.default_ != null) {
                    final value = propertySchema.default_!.toString();
                    final result = resolveType(
                      spec,
                      state,
                      propertySchema.type!,
                      propertySchema,
                    );
                    defaults.add('..${_toDartName(propertyName)} = ${_valueToEscapedValue(result.name, value)}');
                  }
                }
                b.body = Code(
                  <String?>[
                    'b',
                    ...defaults,
                  ].join(),
                );
              }),
              Method(
                (final b) => b
                  ..static = true
                  ..name = 'fromJson'
                  ..lambda = true
                  ..returns = refer('${state.prefix}$identifier')
                  ..requiredParameters.add(
                    Parameter(
                      (final b) => b
                        ..name = 'json'
                        ..type = refer('Object'),
                    ),
                  )
                  ..body = const Code('serializers.deserializeWith(serializer, json)!'),
              ),
              Method(
                (final b) => b
                  ..static = true
                  ..name = 'fromJsonString'
                  ..lambda = true
                  ..returns = refer('${state.prefix}$identifier')
                  ..requiredParameters.add(
                    Parameter(
                      (final b) => b
                        ..name = 'data'
                        ..type = refer('String'),
                    ),
                  )
                  ..body = const Code('serializers.fromJson(serializer, data)!'),
              ),
              Method(
                (final b) => b
                  ..name = 'toJson'
                  ..returns = refer('Map<String, dynamic>')
                  ..lambda = true
                  ..body = const Code('serializers.serializeWith(serializer, this) as Map<String, dynamic>'),
              ),
              Method(
                (final b) => b
                  ..name = 'toJsonString'
                  ..returns = refer('String?')
                  ..lambda = true
                  ..static = true
                  ..requiredParameters.add(
                    Parameter(
                      (final b) => b
                        ..name = 'data'
                        ..type = refer(_makeNullable('${state.prefix}$identifier', true)),
                    ),
                  )
                  ..body = const Code('data == null ? null : serializers.toJson(serializer, data)'),
              ),
              Method(
                (final b) => b
                  ..name = 'serializer'
                  ..returns = refer('Serializer<${state.prefix}$identifier>')
                  ..lambda = true
                  ..static = true
                  ..body = Code("_\$${_toCamelCase('${state.prefix}$identifier')}Serializer")
                  ..type = MethodType.getter,
              ),
            ]);
        },
      ),
    );
  }
  return TypeResultObject(
    '${state.prefix}$identifier',
    fromContentString: fromContentString,
  );
}

TypeResult resolveType(
  final OpenAPI spec,
  final State state,
  final String identifier,
  final Schema schema, {
  final Map<String, Map<String, String>>? extraJsonKeyValues,
  final bool ignoreEnum = false,
  final bool fromContentString = false,
}) {
  TypeResult? result;
  if (schema.ref == null && schema.ofs == null && schema.type == null) {
    return TypeResultObject('JsonObject');
  }
  if (schema.ref != null) {
    final name = schema.ref!.split('/').last;
    result = resolveType(
      spec,
      state,
      name,
      spec.components!.schemas![name]!,
      fromContentString: fromContentString,
    );
  } else if (schema.ofs != null) {
    if (!state.resolvedTypes.contains('${state.prefix}$identifier')) {
      state.resolvedTypes.add('${state.prefix}$identifier');
      final results = schema.ofs!
          .map(
            (final s) => resolveType(
              spec,
              state,
              '$identifier${schema.ofs!.indexOf(s)}',
              s,
            ),
          )
          .toList();

      final fields = <String, String>{};
      for (final result in results) {
        final dartName = _toDartName(result.name.replaceFirst(state.prefix, ''));
        fields[result.name] = _toFieldName(dartName, result.name.replaceFirst(state.prefix, ''));
      }

      state.output.addAll([
        Class(
          (final b) {
            b
              ..name = '${state.prefix}$identifier'
              ..abstract = true
              ..implements.add(
                refer(
                  'Built<${state.prefix}$identifier, ${state.prefix}${identifier}Builder>',
                ),
              )
              ..constructors.addAll([
                Constructor(
                  (final b) => b
                    ..name = '_'
                    ..constant = true,
                ),
                Constructor(
                  (final b) => b
                    ..factory = true
                    ..lambda = true
                    ..optionalParameters.add(
                      Parameter(
                        (final b) => b
                          ..name = 'b'
                          ..type = refer('void Function(${state.prefix}${identifier}Builder)?'),
                      ),
                    )
                    ..redirect = refer('_\$${state.prefix}$identifier'),
                ),
              ])
              ..methods.addAll([
                Method(
                  (final b) {
                    b
                      ..name = 'data'
                      ..returns = refer('JsonObject')
                      ..type = MethodType.getter;
                  },
                ),
                for (final result in results) ...[
                  Method(
                    (final b) {
                      final s = schema.ofs![results.indexOf(result)];
                      b
                        ..name = fields[result.name]
                        ..returns = refer(_makeNullable(result.name, !(schema.allOf?.contains(s) ?? false)))
                        ..type = MethodType.getter
                        ..docs.addAll(_descriptionToDocs(s.description));
                    },
                  ),
                ],
                Method(
                  (final b) => b
                    ..static = true
                    ..name = 'fromJson'
                    ..lambda = true
                    ..returns = refer('${state.prefix}$identifier')
                    ..requiredParameters.add(
                      Parameter(
                        (final b) => b
                          ..name = 'json'
                          ..type = refer('Object'),
                      ),
                    )
                    ..body = const Code('serializers.deserializeWith(serializer, json)!'),
                ),
                Method(
                  (final b) => b
                    ..static = true
                    ..name = 'fromJsonString'
                    ..lambda = true
                    ..returns = refer('${state.prefix}$identifier')
                    ..requiredParameters.add(
                      Parameter(
                        (final b) => b
                          ..name = 'data'
                          ..type = refer('String'),
                      ),
                    )
                    ..body = const Code('serializers.fromJson(serializer, data)!'),
                ),
                Method(
                  (final b) => b
                    ..name = 'toJson'
                    ..returns = refer('Map<String, dynamic>')
                    ..lambda = true
                    ..body = const Code('serializers.serializeWith(serializer, this) as Map<String, dynamic>'),
                ),
                Method(
                  (final b) => b
                    ..name = 'toJsonString'
                    ..returns = refer('String?')
                    ..lambda = true
                    ..static = true
                    ..requiredParameters.add(
                      Parameter(
                        (final b) => b
                          ..name = 'data'
                          ..type = refer(_makeNullable('${state.prefix}$identifier', true)),
                      ),
                    )
                    ..body = const Code('data == null ? null : serializers.toJson(serializer, data)'),
                ),
                Method(
                  (final b) => b
                    ..name = 'serializer'
                    ..returns = refer('Serializer<${state.prefix}$identifier>')
                    ..lambda = true
                    ..static = true
                    ..annotations.add(refer('BuiltValueSerializer').call([], {'custom': refer('true')}))
                    ..body = Code('_\$${state.prefix}${identifier}Serializer()')
                    ..type = MethodType.getter,
                ),
              ]);
          },
        ),
        Class(
          (final b) => b
            ..name = '_\$${state.prefix}${identifier}Serializer'
            ..implements.add(refer('PrimitiveSerializer<${state.prefix}$identifier>'))
            ..fields.addAll([
              Field(
                (final b) => b
                  ..name = 'types'
                  ..modifier = FieldModifier.final$
                  ..type = refer('Iterable<Type>')
                  ..annotations.add(refer('override'))
                  ..assignment = Code('const [${state.prefix}$identifier, _\$${state.prefix}$identifier]'),
              ),
              Field(
                (final b) => b
                  ..name = 'wireName'
                  ..modifier = FieldModifier.final$
                  ..type = refer('String')
                  ..annotations.add(refer('override'))
                  ..assignment = Code("r'${state.prefix}$identifier'"),
              )
            ])
            ..methods.addAll([
              Method((final b) {
                b
                  ..name = 'serialize'
                  ..returns = refer('Object')
                  ..annotations.add(refer('override'))
                  ..requiredParameters.addAll([
                    Parameter(
                      (final b) => b
                        ..name = 'serializers'
                        ..type = refer('Serializers'),
                    ),
                    Parameter(
                      (final b) => b
                        ..name = 'object'
                        ..type = refer('${state.prefix}$identifier'),
                    ),
                  ])
                  ..optionalParameters.add(
                    Parameter(
                      (final b) => b
                        ..name = 'specifiedType'
                        ..type = refer('FullType')
                        ..named = true
                        ..defaultTo = const Code('FullType.unspecified'),
                    ),
                  )
                  ..body = const Code('return object.data.value;');
              }),
              Method((final b) {
                b
                  ..name = 'deserialize'
                  ..returns = refer('${state.prefix}$identifier')
                  ..annotations.add(refer('override'))
                  ..requiredParameters.addAll([
                    Parameter(
                      (final b) => b
                        ..name = 'serializers'
                        ..type = refer('Serializers'),
                    ),
                    Parameter(
                      (final b) => b
                        ..name = 'data'
                        ..type = refer('Object'),
                    ),
                  ])
                  ..optionalParameters.add(
                    Parameter(
                      (final b) => b
                        ..name = 'specifiedType'
                        ..type = refer('FullType')
                        ..named = true
                        ..defaultTo = const Code('FullType.unspecified'),
                    ),
                  )
                  ..body = Code(
                    <String>[
                      'final result = new ${state.prefix}${identifier}Builder()',
                      '..data = JsonObject(data);',
                      if (schema.allOf != null) ...[
                        for (final result in results) ...[
                          'result.${fields[result.name]!} = ${result.deserialize('data', toBuilder: true)};',
                        ],
                      ] else ...[
                        for (final result in results) ...[
                          if (schema.discriminator != null) ...[
                            "if (data['${schema.discriminator!.propertyName}'] == '${result.name.replaceFirst(state.prefix, '')}'",
                            if (schema.discriminator!.mapping != null && schema.discriminator!.mapping!.isNotEmpty) ...[
                              for (final key in schema.discriminator!.mapping!.entries
                                  .where(
                                    (final entry) =>
                                        entry.value.endsWith('/${result.name.replaceFirst(state.prefix, '')}'),
                                  )
                                  .map((final entry) => entry.key)) ...[
                                " ||  data['${schema.discriminator!.propertyName}'] == '$key'",
                              ],
                              ') {',
                            ],
                          ],
                          'try {',
                          'result.${fields[result.name]!} = ${result.deserialize('data', toBuilder: true)};',
                          '} catch (_) {',
                          if (schema.discriminator != null) ...[
                            'rethrow;',
                          ],
                          '}',
                          if (schema.discriminator != null) ...[
                            '}',
                          ],
                        ],
                        if (schema.oneOf != null) ...[
                          "assert([${fields.values.map((final e) => 'result._$e').join(',')}].where((final x) => x != null).length == 1, 'Need oneOf for \${result._data}');",
                        ],
                        if (schema.anyOf != null) ...[
                          "assert([${fields.values.map((final e) => 'result._$e').join(',')}].where((final x) => x != null).length >= 1, 'Need anyOf for \${result._data}');",
                        ],
                      ],
                      'return result.build();',
                    ].join(),
                  );
              }),
            ]),
        ),
      ]);
    }

    result = TypeResultObject('${state.prefix}$identifier');
  } else {
    switch (schema.type) {
      case 'boolean':
        result = TypeResultBase('bool');
        break;
      case 'integer':
        result = TypeResultBase('int');
        break;
      case 'number':
        result = TypeResultBase('num');
        break;
      case 'string':
        switch (schema.format) {
          case 'binary':
            result = TypeResultBase('Uint8List');
            break;
        }

        if (schema.isContentString) {
          result = resolveType(
            spec,
            state,
            identifier,
            schema.contentSchema!,
            fromContentString: true,
          );
          break;
        }

        result = TypeResultBase(
          'String',
        );
        break;
      case 'array':
        if (schema.items != null) {
          final subResult = resolveType(
            spec,
            state,
            identifier,
            schema.items!,
          );
          result = TypeResultBuiltList(
            'BuiltList<${subResult.name}>',
            subResult,
            fromContentString: fromContentString,
          );
        } else {
          result = TypeResultBuiltList(
            'BuiltList<JsonObject>',
            TypeResultObject('JsonObject'),
          );
        }
        break;
      case 'object':
        if (schema.properties == null) {
          if (schema.additionalProperties != null) {
            if (schema.additionalProperties is EmptySchema) {
              result = TypeResultBuiltMap(
                'BuiltMap<String, Object?>',
                TypeResultBase('JsonObject'),
              );
            } else {
              final subResult = resolveType(
                spec,
                state,
                identifier,
                schema.additionalProperties!,
              );
              result = TypeResultBuiltMap(
                'BuiltMap<String, ${subResult.name}>',
                TypeResultBase('JsonObject'),
              );
            }
            break;
          }
          result = TypeResultBase('JsonObject');
          break;
        }
        if (schema.properties!.isEmpty) {
          result = TypeResultBuiltMap(
            'BuiltMap<String, Object?>',
            TypeResultBase('JsonObject'),
          );
          break;
        }

        result = resolveObject(
          spec,
          state,
          identifier,
          schema,
          extraJsonKeyValues: extraJsonKeyValues,
          fromContentString: fromContentString,
        );
        break;
    }
  }

  if (result != null) {
    if (!ignoreEnum && schema.enum_ != null) {
      if (!state.resolvedTypes.contains('${state.prefix}$identifier')) {
        state.resolvedTypes.add('${state.prefix}$identifier');
        state.output.add(
          Class(
            (final b) => b
              ..name = '${state.prefix}$identifier'
              ..extend = refer('EnumClass')
              ..constructors.add(
                Constructor(
                  (final b) => b
                    ..name = '_'
                    ..constant = true
                    ..requiredParameters.add(
                      Parameter(
                        (final b) => b
                          ..name = 'name'
                          ..toSuper = true,
                      ),
                    ),
                ),
              )
              ..fields.addAll(
                schema.enum_!.map(
                  (final value) => Field(
                    (final b) {
                      final result = resolveType(
                        spec,
                        state,
                        '$identifier${_toDartName(value.toString(), uppercaseFirstCharacter: true)}',
                        schema,
                        ignoreEnum: true,
                      );
                      b
                        ..name = _toDartName(value.toString())
                        ..static = true
                        ..modifier = FieldModifier.constant
                        ..type = refer('${state.prefix}$identifier')
                        ..assignment = Code(
                          '_\$${_toCamelCase('${state.prefix}$identifier')}${_toDartName(value.toString())}',
                        );

                      final hasDifferentName = _toDartName(value.toString()) != value.toString();
                      if (hasDifferentName) {
                        if (result.name != 'String' && result.name != 'int') {
                          throw Exception(
                            'Sorry enum values are a bit broken. '
                            'See https://github.com/google/json_serializable.dart/issues/616. '
                            'Please remove the enum values on ${state.prefix}$identifier.',
                          );
                        }
                        b.annotations.add(
                          refer('BuiltValueEnumConst').call(
                            [],
                            {
                              if (hasDifferentName) ...{
                                'wireName': refer(_valueToEscapedValue(result.name, value.toString())),
                              },
                            },
                          ),
                        );
                      }
                    },
                  ),
                ),
              )
              ..methods.addAll([
                Method(
                  (final b) => b
                    ..name = 'values'
                    ..returns = refer('BuiltSet<${state.prefix}$identifier>')
                    ..lambda = true
                    ..static = true
                    ..body = Code('_\$${_toCamelCase('${state.prefix}$identifier')}Values')
                    ..type = MethodType.getter,
                ),
                Method(
                  (final b) => b
                    ..name = 'valueOf'
                    ..returns = refer('${state.prefix}$identifier')
                    ..lambda = true
                    ..static = true
                    ..requiredParameters.add(
                      Parameter(
                        (final b) => b
                          ..name = 'name'
                          ..type = refer(result!.name),
                      ),
                    )
                    ..body = Code('_\$valueOf${state.prefix}$identifier(name)'),
                ),
                Method(
                  (final b) => b
                    ..name = 'serializer'
                    ..returns = refer('Serializer<${state.prefix}$identifier>')
                    ..lambda = true
                    ..static = true
                    ..body = Code("_\$${_toCamelCase('${state.prefix}$identifier')}Serializer")
                    ..type = MethodType.getter,
                ),
              ]),
          ),
        );
      }
      result = TypeResultEnum('${state.prefix}$identifier', result);
    }

    return result;
  }

  throw Exception('Can not convert OpenAPI type "${schema.toJson()}" to a Dart type');
}
