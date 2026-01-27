// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tag_dictionary_entry.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetTagDictionaryEntryCollection on Isar {
  IsarCollection<TagDictionaryEntry> get tagDictionaryEntrys =>
      this.collection();
}

const TagDictionaryEntrySchema = CollectionSchema(
  name: r'TagDictionaryEntry',
  id: 8667931692838297928,
  properties: {
    r'aliases': PropertySchema(
      id: 0,
      name: r'aliases',
      type: IsarType.stringList,
    ),
    r'canonicalTag': PropertySchema(
      id: 1,
      name: r'canonicalTag',
      type: IsarType.string,
    ),
    r'clientId': PropertySchema(
      id: 2,
      name: r'clientId',
      type: IsarType.string,
    ),
    r'createdAt': PropertySchema(
      id: 3,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'isDeleted': PropertySchema(
      id: 4,
      name: r'isDeleted',
      type: IsarType.bool,
    ),
    r'isDirty': PropertySchema(
      id: 5,
      name: r'isDirty',
      type: IsarType.bool,
    ),
    r'lastUsedAt': PropertySchema(
      id: 6,
      name: r'lastUsedAt',
      type: IsarType.dateTime,
    ),
    r'localUpdatedAt': PropertySchema(
      id: 7,
      name: r'localUpdatedAt',
      type: IsarType.dateTime,
    ),
    r'serverUpdatedAt': PropertySchema(
      id: 8,
      name: r'serverUpdatedAt',
      type: IsarType.dateTime,
    ),
    r'syncVersion': PropertySchema(
      id: 9,
      name: r'syncVersion',
      type: IsarType.long,
    ),
    r'useCount': PropertySchema(
      id: 10,
      name: r'useCount',
      type: IsarType.long,
    ),
    r'uuid': PropertySchema(
      id: 11,
      name: r'uuid',
      type: IsarType.string,
    )
  },
  estimateSize: _tagDictionaryEntryEstimateSize,
  serialize: _tagDictionaryEntrySerialize,
  deserialize: _tagDictionaryEntryDeserialize,
  deserializeProp: _tagDictionaryEntryDeserializeProp,
  idName: r'id',
  indexes: {
    r'uuid': IndexSchema(
      id: 2134397340427724972,
      name: r'uuid',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'uuid',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'canonicalTag': IndexSchema(
      id: -143197204889026181,
      name: r'canonicalTag',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'canonicalTag',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _tagDictionaryEntryGetId,
  getLinks: _tagDictionaryEntryGetLinks,
  attach: _tagDictionaryEntryAttach,
  version: '3.1.0+1',
);

int _tagDictionaryEntryEstimateSize(
  TagDictionaryEntry object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.aliases.length * 3;
  {
    for (var i = 0; i < object.aliases.length; i++) {
      final value = object.aliases[i];
      bytesCount += value.length * 3;
    }
  }
  bytesCount += 3 + object.canonicalTag.length * 3;
  {
    final value = object.clientId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.uuid.length * 3;
  return bytesCount;
}

void _tagDictionaryEntrySerialize(
  TagDictionaryEntry object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeStringList(offsets[0], object.aliases);
  writer.writeString(offsets[1], object.canonicalTag);
  writer.writeString(offsets[2], object.clientId);
  writer.writeDateTime(offsets[3], object.createdAt);
  writer.writeBool(offsets[4], object.isDeleted);
  writer.writeBool(offsets[5], object.isDirty);
  writer.writeDateTime(offsets[6], object.lastUsedAt);
  writer.writeDateTime(offsets[7], object.localUpdatedAt);
  writer.writeDateTime(offsets[8], object.serverUpdatedAt);
  writer.writeLong(offsets[9], object.syncVersion);
  writer.writeLong(offsets[10], object.useCount);
  writer.writeString(offsets[11], object.uuid);
}

TagDictionaryEntry _tagDictionaryEntryDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = TagDictionaryEntry();
  object.aliases = reader.readStringList(offsets[0]) ?? [];
  object.canonicalTag = reader.readString(offsets[1]);
  object.clientId = reader.readStringOrNull(offsets[2]);
  object.createdAt = reader.readDateTime(offsets[3]);
  object.id = id;
  object.isDeleted = reader.readBool(offsets[4]);
  object.isDirty = reader.readBool(offsets[5]);
  object.lastUsedAt = reader.readDateTimeOrNull(offsets[6]);
  object.localUpdatedAt = reader.readDateTime(offsets[7]);
  object.serverUpdatedAt = reader.readDateTimeOrNull(offsets[8]);
  object.syncVersion = reader.readLong(offsets[9]);
  object.useCount = reader.readLong(offsets[10]);
  object.uuid = reader.readString(offsets[11]);
  return object;
}

P _tagDictionaryEntryDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringList(offset) ?? []) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readDateTime(offset)) as P;
    case 4:
      return (reader.readBool(offset)) as P;
    case 5:
      return (reader.readBool(offset)) as P;
    case 6:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 7:
      return (reader.readDateTime(offset)) as P;
    case 8:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 9:
      return (reader.readLong(offset)) as P;
    case 10:
      return (reader.readLong(offset)) as P;
    case 11:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _tagDictionaryEntryGetId(TagDictionaryEntry object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _tagDictionaryEntryGetLinks(
    TagDictionaryEntry object) {
  return [];
}

void _tagDictionaryEntryAttach(
    IsarCollection<dynamic> col, Id id, TagDictionaryEntry object) {
  object.id = id;
}

extension TagDictionaryEntryByIndex on IsarCollection<TagDictionaryEntry> {
  Future<TagDictionaryEntry?> getByUuid(String uuid) {
    return getByIndex(r'uuid', [uuid]);
  }

  TagDictionaryEntry? getByUuidSync(String uuid) {
    return getByIndexSync(r'uuid', [uuid]);
  }

  Future<bool> deleteByUuid(String uuid) {
    return deleteByIndex(r'uuid', [uuid]);
  }

  bool deleteByUuidSync(String uuid) {
    return deleteByIndexSync(r'uuid', [uuid]);
  }

  Future<List<TagDictionaryEntry?>> getAllByUuid(List<String> uuidValues) {
    final values = uuidValues.map((e) => [e]).toList();
    return getAllByIndex(r'uuid', values);
  }

  List<TagDictionaryEntry?> getAllByUuidSync(List<String> uuidValues) {
    final values = uuidValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'uuid', values);
  }

  Future<int> deleteAllByUuid(List<String> uuidValues) {
    final values = uuidValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'uuid', values);
  }

  int deleteAllByUuidSync(List<String> uuidValues) {
    final values = uuidValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'uuid', values);
  }

  Future<Id> putByUuid(TagDictionaryEntry object) {
    return putByIndex(r'uuid', object);
  }

  Id putByUuidSync(TagDictionaryEntry object, {bool saveLinks = true}) {
    return putByIndexSync(r'uuid', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByUuid(List<TagDictionaryEntry> objects) {
    return putAllByIndex(r'uuid', objects);
  }

  List<Id> putAllByUuidSync(List<TagDictionaryEntry> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'uuid', objects, saveLinks: saveLinks);
  }

  Future<TagDictionaryEntry?> getByCanonicalTag(String canonicalTag) {
    return getByIndex(r'canonicalTag', [canonicalTag]);
  }

  TagDictionaryEntry? getByCanonicalTagSync(String canonicalTag) {
    return getByIndexSync(r'canonicalTag', [canonicalTag]);
  }

  Future<bool> deleteByCanonicalTag(String canonicalTag) {
    return deleteByIndex(r'canonicalTag', [canonicalTag]);
  }

  bool deleteByCanonicalTagSync(String canonicalTag) {
    return deleteByIndexSync(r'canonicalTag', [canonicalTag]);
  }

  Future<List<TagDictionaryEntry?>> getAllByCanonicalTag(
      List<String> canonicalTagValues) {
    final values = canonicalTagValues.map((e) => [e]).toList();
    return getAllByIndex(r'canonicalTag', values);
  }

  List<TagDictionaryEntry?> getAllByCanonicalTagSync(
      List<String> canonicalTagValues) {
    final values = canonicalTagValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'canonicalTag', values);
  }

  Future<int> deleteAllByCanonicalTag(List<String> canonicalTagValues) {
    final values = canonicalTagValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'canonicalTag', values);
  }

  int deleteAllByCanonicalTagSync(List<String> canonicalTagValues) {
    final values = canonicalTagValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'canonicalTag', values);
  }

  Future<Id> putByCanonicalTag(TagDictionaryEntry object) {
    return putByIndex(r'canonicalTag', object);
  }

  Id putByCanonicalTagSync(TagDictionaryEntry object, {bool saveLinks = true}) {
    return putByIndexSync(r'canonicalTag', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByCanonicalTag(List<TagDictionaryEntry> objects) {
    return putAllByIndex(r'canonicalTag', objects);
  }

  List<Id> putAllByCanonicalTagSync(List<TagDictionaryEntry> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'canonicalTag', objects, saveLinks: saveLinks);
  }
}

extension TagDictionaryEntryQueryWhereSort
    on QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QWhere> {
  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension TagDictionaryEntryQueryWhere
    on QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QWhereClause> {
  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterWhereClause>
      idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterWhereClause>
      idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterWhereClause>
      idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterWhereClause>
      uuidEqualTo(String uuid) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'uuid',
        value: [uuid],
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterWhereClause>
      uuidNotEqualTo(String uuid) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'uuid',
              lower: [],
              upper: [uuid],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'uuid',
              lower: [uuid],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'uuid',
              lower: [uuid],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'uuid',
              lower: [],
              upper: [uuid],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterWhereClause>
      canonicalTagEqualTo(String canonicalTag) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'canonicalTag',
        value: [canonicalTag],
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterWhereClause>
      canonicalTagNotEqualTo(String canonicalTag) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'canonicalTag',
              lower: [],
              upper: [canonicalTag],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'canonicalTag',
              lower: [canonicalTag],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'canonicalTag',
              lower: [canonicalTag],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'canonicalTag',
              lower: [],
              upper: [canonicalTag],
              includeUpper: false,
            ));
      }
    });
  }
}

extension TagDictionaryEntryQueryFilter
    on QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QFilterCondition> {
  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      aliasesElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'aliases',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      aliasesElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'aliases',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      aliasesElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'aliases',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      aliasesElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'aliases',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      aliasesElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'aliases',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      aliasesElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'aliases',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      aliasesElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'aliases',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      aliasesElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'aliases',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      aliasesElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'aliases',
        value: '',
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      aliasesElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'aliases',
        value: '',
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      aliasesLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'aliases',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      aliasesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'aliases',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      aliasesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'aliases',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      aliasesLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'aliases',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      aliasesLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'aliases',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      aliasesLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'aliases',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      canonicalTagEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'canonicalTag',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      canonicalTagGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'canonicalTag',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      canonicalTagLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'canonicalTag',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      canonicalTagBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'canonicalTag',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      canonicalTagStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'canonicalTag',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      canonicalTagEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'canonicalTag',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      canonicalTagContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'canonicalTag',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      canonicalTagMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'canonicalTag',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      canonicalTagIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'canonicalTag',
        value: '',
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      canonicalTagIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'canonicalTag',
        value: '',
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      clientIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'clientId',
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      clientIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'clientId',
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      clientIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'clientId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      clientIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'clientId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      clientIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'clientId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      clientIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'clientId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      clientIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'clientId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      clientIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'clientId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      clientIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'clientId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      clientIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'clientId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      clientIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'clientId',
        value: '',
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      clientIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'clientId',
        value: '',
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      createdAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      createdAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      createdAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      isDeletedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isDeleted',
        value: value,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      isDirtyEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isDirty',
        value: value,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      lastUsedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'lastUsedAt',
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      lastUsedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'lastUsedAt',
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      lastUsedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastUsedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      lastUsedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastUsedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      lastUsedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastUsedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      lastUsedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastUsedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      localUpdatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'localUpdatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      localUpdatedAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'localUpdatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      localUpdatedAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'localUpdatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      localUpdatedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'localUpdatedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      serverUpdatedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'serverUpdatedAt',
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      serverUpdatedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'serverUpdatedAt',
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      serverUpdatedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'serverUpdatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      serverUpdatedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'serverUpdatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      serverUpdatedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'serverUpdatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      serverUpdatedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'serverUpdatedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      syncVersionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'syncVersion',
        value: value,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      syncVersionGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'syncVersion',
        value: value,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      syncVersionLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'syncVersion',
        value: value,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      syncVersionBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'syncVersion',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      useCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'useCount',
        value: value,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      useCountGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'useCount',
        value: value,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      useCountLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'useCount',
        value: value,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      useCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'useCount',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      uuidEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'uuid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      uuidGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'uuid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      uuidLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'uuid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      uuidBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'uuid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      uuidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'uuid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      uuidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'uuid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      uuidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'uuid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      uuidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'uuid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      uuidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'uuid',
        value: '',
      ));
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterFilterCondition>
      uuidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'uuid',
        value: '',
      ));
    });
  }
}

extension TagDictionaryEntryQueryObject
    on QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QFilterCondition> {}

extension TagDictionaryEntryQueryLinks
    on QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QFilterCondition> {}

extension TagDictionaryEntryQuerySortBy
    on QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QSortBy> {
  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterSortBy>
      sortByCanonicalTag() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'canonicalTag', Sort.asc);
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterSortBy>
      sortByCanonicalTagDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'canonicalTag', Sort.desc);
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterSortBy>
      sortByClientId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'clientId', Sort.asc);
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterSortBy>
      sortByClientIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'clientId', Sort.desc);
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterSortBy>
      sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterSortBy>
      sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterSortBy>
      sortByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.asc);
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterSortBy>
      sortByIsDeletedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.desc);
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterSortBy>
      sortByIsDirty() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDirty', Sort.asc);
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterSortBy>
      sortByIsDirtyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDirty', Sort.desc);
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterSortBy>
      sortByLastUsedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUsedAt', Sort.asc);
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterSortBy>
      sortByLastUsedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUsedAt', Sort.desc);
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterSortBy>
      sortByLocalUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localUpdatedAt', Sort.asc);
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterSortBy>
      sortByLocalUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localUpdatedAt', Sort.desc);
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterSortBy>
      sortByServerUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'serverUpdatedAt', Sort.asc);
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterSortBy>
      sortByServerUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'serverUpdatedAt', Sort.desc);
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterSortBy>
      sortBySyncVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncVersion', Sort.asc);
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterSortBy>
      sortBySyncVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncVersion', Sort.desc);
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterSortBy>
      sortByUseCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'useCount', Sort.asc);
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterSortBy>
      sortByUseCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'useCount', Sort.desc);
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterSortBy>
      sortByUuid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uuid', Sort.asc);
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterSortBy>
      sortByUuidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uuid', Sort.desc);
    });
  }
}

extension TagDictionaryEntryQuerySortThenBy
    on QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QSortThenBy> {
  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterSortBy>
      thenByCanonicalTag() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'canonicalTag', Sort.asc);
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterSortBy>
      thenByCanonicalTagDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'canonicalTag', Sort.desc);
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterSortBy>
      thenByClientId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'clientId', Sort.asc);
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterSortBy>
      thenByClientIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'clientId', Sort.desc);
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterSortBy>
      thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterSortBy>
      thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterSortBy>
      thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterSortBy>
      thenByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.asc);
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterSortBy>
      thenByIsDeletedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.desc);
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterSortBy>
      thenByIsDirty() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDirty', Sort.asc);
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterSortBy>
      thenByIsDirtyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDirty', Sort.desc);
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterSortBy>
      thenByLastUsedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUsedAt', Sort.asc);
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterSortBy>
      thenByLastUsedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUsedAt', Sort.desc);
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterSortBy>
      thenByLocalUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localUpdatedAt', Sort.asc);
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterSortBy>
      thenByLocalUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localUpdatedAt', Sort.desc);
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterSortBy>
      thenByServerUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'serverUpdatedAt', Sort.asc);
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterSortBy>
      thenByServerUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'serverUpdatedAt', Sort.desc);
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterSortBy>
      thenBySyncVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncVersion', Sort.asc);
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterSortBy>
      thenBySyncVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncVersion', Sort.desc);
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterSortBy>
      thenByUseCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'useCount', Sort.asc);
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterSortBy>
      thenByUseCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'useCount', Sort.desc);
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterSortBy>
      thenByUuid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uuid', Sort.asc);
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QAfterSortBy>
      thenByUuidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uuid', Sort.desc);
    });
  }
}

extension TagDictionaryEntryQueryWhereDistinct
    on QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QDistinct> {
  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QDistinct>
      distinctByAliases() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'aliases');
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QDistinct>
      distinctByCanonicalTag({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'canonicalTag', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QDistinct>
      distinctByClientId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'clientId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QDistinct>
      distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QDistinct>
      distinctByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isDeleted');
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QDistinct>
      distinctByIsDirty() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isDirty');
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QDistinct>
      distinctByLastUsedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastUsedAt');
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QDistinct>
      distinctByLocalUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'localUpdatedAt');
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QDistinct>
      distinctByServerUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'serverUpdatedAt');
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QDistinct>
      distinctBySyncVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'syncVersion');
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QDistinct>
      distinctByUseCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'useCount');
    });
  }

  QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QDistinct>
      distinctByUuid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'uuid', caseSensitive: caseSensitive);
    });
  }
}

extension TagDictionaryEntryQueryProperty
    on QueryBuilder<TagDictionaryEntry, TagDictionaryEntry, QQueryProperty> {
  QueryBuilder<TagDictionaryEntry, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<TagDictionaryEntry, List<String>, QQueryOperations>
      aliasesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'aliases');
    });
  }

  QueryBuilder<TagDictionaryEntry, String, QQueryOperations>
      canonicalTagProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'canonicalTag');
    });
  }

  QueryBuilder<TagDictionaryEntry, String?, QQueryOperations>
      clientIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'clientId');
    });
  }

  QueryBuilder<TagDictionaryEntry, DateTime, QQueryOperations>
      createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<TagDictionaryEntry, bool, QQueryOperations> isDeletedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isDeleted');
    });
  }

  QueryBuilder<TagDictionaryEntry, bool, QQueryOperations> isDirtyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isDirty');
    });
  }

  QueryBuilder<TagDictionaryEntry, DateTime?, QQueryOperations>
      lastUsedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastUsedAt');
    });
  }

  QueryBuilder<TagDictionaryEntry, DateTime, QQueryOperations>
      localUpdatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'localUpdatedAt');
    });
  }

  QueryBuilder<TagDictionaryEntry, DateTime?, QQueryOperations>
      serverUpdatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'serverUpdatedAt');
    });
  }

  QueryBuilder<TagDictionaryEntry, int, QQueryOperations>
      syncVersionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'syncVersion');
    });
  }

  QueryBuilder<TagDictionaryEntry, int, QQueryOperations> useCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'useCount');
    });
  }

  QueryBuilder<TagDictionaryEntry, String, QQueryOperations> uuidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'uuid');
    });
  }
}
