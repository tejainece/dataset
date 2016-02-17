part of dataset;

class Column {
  final String name;
  /*final*/ String type;
  List data;
  bool force = false;

  /// Function to pre-process a column's value before it is coerced.
  final Function before;

  /// Only set if time type.
  final String format;
  var _id;

  /// Only set for computed columns;
  Function func;

  /// Column objects make up the columns contained in a dataset and
  /// are returned by some methods such as [DataView.column].
  Column(this.name, this.type,
      {List data, before(value), id, this.format, this.func})
      : data = (data == null ? [] : data),
        before = (before == null ? (v) => v : before) {
    _id = (id != null) ? id : uniqueId();
  }

  /// Converts any value to this column's type for a given position in some
  /// source array.
  num toNumeric(value) => types[type].numeric(value);

  /// Internal function used to return the numeric value of a given input in a
  /// column. Index is used as this is currently the return value for numeric
  /// coercion of string values.
  ///
  ///     var col = new Column('inoculated', 'boolean',
  ///       data: [true, false, false, true]);
  ///
  ///     col.numericAt(0);
  ///     col.numericAt(1);
  num numericAt(int index) => toNumeric(data[index]);

  /// Coerces all the data in the column's data array to the appropriate type.
  ///
  ///     var col = new Column('amount', 'number',
  ///       data: [2, 3, '4']);
  ///
  ///     col.data;
  ///     col.coerce();
  ///     col.data;
  coerce() {
    data = data.map((datum) => types[type].coerce(datum));
  }

  /// If this is a computed column, it calculates the value for this column
  /// and adds it to the data. Specify the [row] from which column is computed
  /// and the [index] at which this value will get added.
  dynamic compute(row, [int index]) {
    if (func != null) {
      var val = func(row);
      if (index != null) {
        try {
          RangeError.checkValidIndex(index, data);
          data[index] = val;
        } on RangeError catch (_) {
          data.add(val);
        }
      } else {
        data.add(val);
      }
      return val;
    }
    return null;
  }

  /// Returns true if this is a computed column. False otherwise.
  bool isComputed() => func != null;

  _sum() => data.reduce((a, b) => a + b);

  _mean() {
    var m = 0;
    for (var j = 0; j < data.length; j++) {
      m += numericAt(j);
    }
    m /= data.length;
    return types[type].coerce(m, format);
  }

  _median() => types[type].coerce(__median(data), format);

  _max() {
    var max = double.NEGATIVE_INFINITY;
    for (var j = 0; j < data.length; j++) {
      if (data[j] != null) {
        var n = types[type].numeric(data[j]);
        if (types['number'].compare(n, max) > 0) {
          max = this.numericAt(j);
        }
      }
    }

    return types[this.type].coerce(max, format);
  }

  _min() {
    var min = double.INFINITY;
    for (var j = 0; j < data.length; j++) {
      if (data[j] != null) {
        var n = types[type].numeric(data[j]);
        if (types['number'].compare(n, min) < 0) {
          min = numericAt(j);
        }
      }
    }
    return types[type].coerce(min, format);
  }
}

class DataView {
  final Dataset parent;
  var /*Function*/ filter;

  /// A filter for columns. A single or multiple column names.
//  var /*String|String[]*/ filterColumns;

  /// A filter for rows. A rowId or a filter function that takes
  /// in a row and returns true if it passes the criteria.
//  var /*Number|Function*/ filterRows;

  bool syncable;
  String idAttribute;
  List<Column> _columns;

  Map _rowPositionById;
  Map<String, int> _columnPositionByName;
  List _rowIdByPosition;
  int length;
  Comparator<Map> comparator;
  List<Column> _computedColumns;

  StreamController<DatasetEvent> _addCtrl,
      _changeCtrl,
      _updateCtrl,
      _deleteCtrl,
      _removeCtrl;
  StreamController _resetCtrl, _sortCtrl;

  DataView._()
      : parent = null,
        filter = null;

  /// A `DataView` is an immutable version of dataset. It is the result of
  /// selecting a subset of the data using the [Dataset.where] call.
  /// If the dataset is syncing, this view will be updated when changes take
  /// place in the original dataset. A [Dataset] also extends from
  /// [DataView]. All the methods available on a dataview will also be
  /// available on the dataset.
  DataView(this.parent, [filter]) {
    if (parent == null) {
      throw new ArgumentError.notNull('parent');
    }
//    _initialize(options);
//  }
//
//  _initialize(options) {
    // is this a syncable dataset? if so, pull
    // required methoMiso and mark this as a syncable dataset.
    if (parent.syncable == true) {
//      _.extend(this, Miso.Events);
      _setupSync();
      syncable = true;
    } else {
      syncable = false;
    }

    idAttribute = parent.idAttribute;

    // save filter
    this.filter = {};
//    this.filter['columns'] = _.bind(this._columnFilter(filter['columns']), this);
//    this.filter['rows'] = _.bind(this._rowFilter(filter['rows']), this);
    this.filter['columns'] =
        this._columnFilter(filter is Map ? filter['columns'] : null);
    this.filter['rows'] =
        this._rowFilter(filter is Map ? filter['rows'] : null);

    // initialize columns.
    _columns = _selectData();

    Builder.cacheColumns(this);
    Builder.cacheRows(this);

    // bind to parent if syncable
    if (syncable) {
      parent.onChange.listen(_sync);
    }
  }

  void _setupSync() {
    _addCtrl = new StreamController.broadcast();
    _changeCtrl = new StreamController.broadcast();
    _updateCtrl = new StreamController.broadcast();
    _deleteCtrl = new StreamController.broadcast();
    _removeCtrl = new StreamController.broadcast();
    _resetCtrl = new StreamController.broadcast();
    _sortCtrl = new StreamController.broadcast();
  }

  /// Fired when adding a row to the dataset by calling [add].
  Stream<DatasetEvent> get onAdd => _addCtrl?.stream;

  /// Fired when calling [add], [remove] or [update].
  Stream<DatasetEvent> get onChange => _changeCtrl?.stream;

  /// Fired when updating a row in the dataset by calling [update].
  Stream<DatasetEvent> get onUpdate => _updateCtrl?.stream;
  Stream<DatasetEvent> get onDelete => _deleteCtrl?.stream;

  /// Fired when removing a row from the dataset by calling [remove].
  Stream<DatasetEvent> get onRemove => _removeCtrl?.stream;

  /// Fired when a dataset has been reset.
  Stream get onReset => _resetCtrl?.stream;

  /// Fired when a dataset has been sorted.
  Stream get onSort => _sortCtrl?.stream;

  /// Syncs up the current view based on a passed delta.
  _sync(DatasetEvent event) {
    var deltas = event.deltas;
    String eventType = null;

    // iterate over deltas and update rows that are affected.
    deltas.asMap().forEach((deltaIndex, d) {
      // find row position based on delta _id
      var rowPos = this._rowPositionById[d.id];

      // ==== ADD NEW ROW

      if (rowPos == null && d.isAdd()) {
        // this is an add event, since we couldn't find an
        // existing row to update and now need to just add a new
        // one. Use the delta's changed properties as the new row
        // if it passes the filter.
        if (this.filter.rows && this.filter.rows(d.changed)) {
          this._add(d.changed);
          eventType = "add";
        }
      } else {
        //==== UPDATE EXISTING ROW
        if (rowPos == "undefined") {
          return;
        }

        // iterate over each changed property and update the value
        d.changed.forEach((columnName, newValue) {
          // find col position based on column name
          var colPos = _columnPositionByName[columnName];
          if (colPos == null) {
            return;
          }
          _columns[colPos].data[rowPos] = newValue;

          eventType = "update";
        });
      }

      // ==== DELETE ROW (either by event or by filter.)
      // TODO check if the row still passes filter, if not
      // delete it.
      var row = this.rowByPosition(rowPos);

      // if this is a delete event OR the row no longer
      // passes the filter, remove it.
      if (d.isRemove() || (filter['row'] != null && !filter['row'](row))) {
        // Since this is now a delete event, we need to convert it
        // to such so that any child views, know how to interpet it.

        var newDelta = new Delta._(old: rowByPosition(rowPos), changed: {});
        newDelta.id = d.id;

        // replace the old delta with this delta
        event.deltas[deltaIndex] = newDelta;

        // remove row since it doesn't match the filter.
        _remove(rowPos);
        eventType = "delete";
      }
    });

    // trigger any subscribers
    if (this.syncable) {
      switch (eventType) {
        case "add":
          _addCtrl.add(event);
          break;
        case "update":
          _updateCtrl.add(event);
          break;
        case "delete":
          _deleteCtrl.add(event);
          break;
      }
      _changeCtrl.add(event);
    }
  }

  /// Used to create Dataviews, subsets of data based on a set of filters.
  /// Filtration can be applied to both rows & columns and for syncing
  /// datasets changes in the parent dataset from which the dataview was
  /// created will be reflected in the dataview.
  DataView where(filter) {
    if (filter == null) {
      filter = {};
    } else if (filter is Function) {
      filter = {'rows': filter};
    }

    return new DataView(this, filter);
  }

  _selectData() {
    var selectedColumns = <Column>[];

    parent._columns.forEach((parentColumn) {
      // check if this column passes the column filter
      if (filter['columns'](parentColumn)) {
        selectedColumns.add(new Column(parentColumn.name, parentColumn.type,
            data: [], id: parentColumn._id));
      }
    });

    // get the data that passes the row filter.
    parent.each((row, _) {
      if (!filter['rows'](row)) {
        return;
      }

      for (var i = 0; i < selectedColumns.length; i++) {
        selectedColumns[i].data.add(row[selectedColumns[i].name]);
      }
    });

    return selectedColumns;
  }

  /// {Function|String} columnFilter - function or column name
  ///
  /// Returns normalized version of the column filter function that can be
  /// executed.
  Function _columnFilter(columnFilter) {
    Function columnSelector;

    // if no column filter is specified, then just
    // return a passthrough function that will allow
    // any column through.
    if (columnFilter == null) {
      columnSelector = (Column column) => true;
    } else {
      //array
      if (columnFilter is String) {
        columnFilter = [columnFilter];
      }
      columnFilter.add(idAttribute);
      columnSelector = (Column column) {
        return columnFilter.contains(column.name);
      };
    }

    return columnSelector;
  }

  /// Returns normalized row filter function that can be executed.
  Function _rowFilter(rowFilter) {
    var rowSelector;

    //support for a single ID;
    if (rowFilter is num) {
      rowFilter = [rowFilter];
    }

    if (rowFilter == null) {
      rowSelector = (Map row) => true;
    } else if (rowFilter is Function) {
      rowSelector = rowFilter;
    } else {
      //array
      rowSelector = (Map row) {
        return rowFilter.contains(row[idAttribute]);
      };
    }

    return rowSelector;
  }

  /// View a column by [name].
  ///
  ///     var ds = new Dataset(
  ///       data: [
  ///         { one : 1, two : 4, three : 7 },
  ///         { one : 2, two : 5, three : 8 }
  ///       ]
  ///     );
  ///
  ///     ds.fetch(
  ///       success: () {
  ///         print(this.column('one').data);
  ///       }
  ///     );
  Column column(String name) => _column(name);

  Column _column(String name) {
    if (_columnPositionByName == null) {
      return null;
    }
    var pos = _columnPositionByName[name];
    if (pos != null && pos >= 0 && pos < _columns.length) {
      return _columns[pos];
    } else {
      return null;
    }
  }

  /// Dataset view of the given columns.
  ///
  ///     var ds = new Dataset(
  ///       data: [
  ///         { one : 1, two : 4, three : 7 },
  ///         { one : 2, two : 5, three : 8 }
  ///       ]
  ///     );
  ///
  ///     ds.fetch(success: () {
  ///       var oneTwo = this.columns(['one','two']);
  ///       print(ds.columnNames());
  ///       print(oneTwo.columnNames());
  ///     });
  DataView columns(List<String> columnsArray) {
    return new DataView(this, {'columns': columnsArray});
  }

  /// The names of all columns, not including id column.
  List<String> columnNames() {
    var cols = _columns.map((c) => c.name);
    return cols.where((colName) {
      return colName != idAttribute && colName != '_oids';
    }).toList();
  }

  /// Checks for the existance of a column and returns true/false
  bool hasColumn(String name) => _columnPositionByName.containsKey(name);

  /// Iterates over all rows in the dataset. Each row is not a direct
  /// reference to the data and thus should not be altered in any way.
  each(iterator(row, int i)) {
    for (var i = 0; i < length; i++) {
      iterator(rowByPosition(i), i);
    }
  }

  /// Iterates over all rows in the dataset in reverse order. Each row is not
  /// a direct reference to the data and thus should not be altered in any
  /// way.
  reverseEach(iterator(row, int i)) {
    for (var i = length - 1; i >= 0; i--) {
      iterator(rowByPosition(i), i);
    }
  }

  /// Iterates over each column. Direct column references, not arrays so
  /// modifying data may cause internal inconsistencies.
  eachColumn(iterator(String name, Column col, int i)) {
    // skip id col
    var cols = columnNames();
    for (var i = 0; i < cols.length; i++) {
      iterator(cols[i], column(cols[i]), i);
    }
  }

  /// Fetches a row object at a specified position. Note that the returned row
  /// object is NOT a direct reference to the data and thus any changes to it
  /// will not alter the original data.
  Map rowByPosition(int i) => _row(i);

  /// Fetches a row object with a specific _id. Note that the returned row
  /// object is NOT a direct reference to the data and thus any changes to it
  /// will not alter the original data.
  rowById(num id) => _row(_rowPositionById[id]);

  Map _row(int pos) {
    var row = {};
    _columns.forEach((column) {
      try {
        RangeError.checkValidIndex(pos, column.data);
        row[column.name] = column.data[pos];
      } on RangeError catch (_) {
//        row[column.name] = null;
      }
    });
    return row;
  }

  void _remove(num rowId) {
    var rowPos = _rowPositionById[rowId];

    // remove all values
    _columns.forEach((column) {
      column.data.removeAt(rowPos);
    });

    // update caches
    _rowPositionById.remove(rowId);
    _rowIdByPosition.removeAt(rowPos);
    length--;
  }

  void _add(Map row, [bool silent = false]) {
    // first coerce all the values appropriatly
    row.forEach((key, value) {
      var column = this.column(key);

      // is this a computed column? if so throw an error
      if (column.isComputed()) {
        throw "You're trying to update a computed column. Those get computed!";
      }

      // if we suddenly see values for data that didn't exist before as a column
      // just drop it. First fetch defines the column structure.
      if (column != null) {
        var typ = types[column.type];

        // test if value matches column type
        if (column.force || typ.test(row[column.name], column.format)) {
          // do we have a before filter? If so, pass it through that first
          if (column.before != null) {
            row[column.name] = column.before(row[column.name]);
          }

          // coerce it.
          row[column.name] = typ.coerce(row[column.name], column.format);
        } else {
          throw ("incorrect value '${row[column.name]}' of type " +
              typeOf(row[column.name], column.format) +
              " passed to column '${column.name}' with type ${column.type}");
        }
      }
    });

    // do we have any computed columns? If so we need to calculate their values.
    if (_computedColumns != null) {
      _computedColumns.forEach((column) {
        var newVal = column.compute(row);
        row[column.name] = newVal;
      });
    }

    // if we don't have a comparator, just append them at the end.
    if (this.comparator == null) {
      // add all data
      _columns.forEach((column) {
        if (!column.isComputed()) {
          column.data.add(row[column.name] != null ? row[column.name] : null);
        }
      });

      length++;

      // add row indeces to the cache
      _rowIdByPosition = _rowIdByPosition ?? [];
      _rowPositionById = _rowPositionById ?? {};

      // if this row already exists, throw an error
      if (_rowPositionById.containsKey(row[this.idAttribute])) {
        throw "The id ${row[this.idAttribute]} is not unique. The " +
            "$idAttribute column must be unique";
      }

      _rowPositionById[row[idAttribute]] = _rowIdByPosition.length;
      _rowIdByPosition.add(row[idAttribute]);

      // otherwise insert them in the right place. This is a somewhat
      // expensive operation.
    } else {
//      insertAt(at, value, into) {
//        Array.prototype.splice.apply(into, [at, 0].concat(value));
//      }

      var i;
      length++;
      for (i = 0; i < length; i++) {
        var row2 = rowByPosition(i);
        if (row2[this.idAttribute] == null || comparator(row, row2) < 0) {
          _columns.forEach((column) {
//            insertAt(i, (row[column.name] ? row[column.name] : null), column.data);
            column.data.insert(i, row[column.name]);
          });

          break;
        }
      }

      // rebuild position cache...
      // we could splice it in but its safer this way.
      _rowIdByPosition = [];
      _rowPositionById = {};
      each((row, i) {
        _rowIdByPosition.add(row[idAttribute]);
        _rowPositionById[row[idAttribute]] = i;
      });
    }
  }

  /// Shorthand for `DataView.where(rows :rowFilter)`. If run with no filter
  /// will return all rows.
  DataView rows(filter) => new DataView(this, {'rows': filter});

  /// Sorts the dataset according to the comparator. A comparator can either be
  /// passed in as part of the options object or have been defined on the
  /// dataset already, for example as part of the initialization block.
  ///
  /// Roughly taken from here:
  ///     http://jxlib.googlecode.com/svn-history/r977/trunk/src/Source/Data/heapsort.js
  ///
  /// License:
  ///     Copyright (c) 2009, Jon Bomgardner.
  ///     This file is licensed under an MIT style license
  void sort([comparator(a, b), bool silent = false]) {
    var cachedRows = new List(length);

    if (comparator != null) {
      this.comparator = comparator;
    }
    if (this.comparator == null) {
      throw "Cannot sort without this.comparator.";
    }

    // cache rows
    for (var i = 0; i < length; i++) {
      cachedRows[i] = _row(i);
    }

    cachedRows.sort(this.comparator);

    // iterate through cached rows, overwriting data in columns
    var i = cachedRows.length;
    while (i-- != 0) {
      var row = cachedRows[i];

      _rowIdByPosition[i] = row[idAttribute];
      _rowPositionById[row[idAttribute]] = i;

      var j = _columns.length;
      while (j-- != 0) {
        var col = _columns[j];
        col.data[i] = row[col.name];
      }
    }

    if (syncable && !silent) {
      _sortCtrl.add(null);
    }
  }

  /// Exports a version of the dataset in json format.
  List toJSON() {
    var rows = [];
    for (var i = 0; i < this.length; i++) {
      rows.add(rowByPosition(i));
    }
    return rows;
  }

  // Products

  // finds the column objects that match the single/multiple
  // input columns. Helper method.
  List<Column> _findColumns(List<String> columns) {
    var columnObjects = [];

    // if no column names were specified, get all column names.
    if (columns == null) {
      columns = columnNames();
    }

    // convert columns to an array in case we only got one column name.
//    columns = (columns is List) ? columns : [columns];

    // assemble actual column objecets together.
    columns.forEach((column) {
      column = _columns[_columnPositionByName[column]];
      columnObjects.add(column);
    });

    return columnObjects;
  }

  /// If the dataset has `sync` enabled this will return a [Product] that
  /// can be used to bind events to and access the current value. Otherwise
  /// it will return the current value - the sum of the numeric form of the
  /// values in the column.
  ProductFunc get sum => Product.define(this, (columns) {
        columns.forEach((col) {
          if (col.type == types['time'].name) {
            throw "Can't sum up time";
          }
        });
        return columns.map((c) => c._sum()).reduce((a, b) => a + b);
      });

  /// If the dataset has `sync` enabled this will return a [Product] that
  /// can be used to bind events to and access the current value. Otherwise
  /// it will return the current value - the highest numeric value in that
  /// column.
  ProductFunc get max => Product.define(this, (columns) {
        return columns.map((c) => c._max()).reduce(math.max);
      });

  /// If the dataset has `sync` enabled this will return a [Product] that
  /// can be used to bind events to and access the current value.  Otherwise
  /// it will return the current value - the lowest numeric value in that
  /// column.
  ProductFunc get min => Product.define(this, (columns) {
        return columns.map((c) => c._min()).reduce(math.min);
      });

  /// If the dataset has `sync` enabled this will return a [Product] that
  /// can be used to bind events to and access the current value.  Otherwise
  /// it will return the current value - the mean or average of the numeric
  /// form of the values in the column.
  ProductFunc get mean => Product.define(this, (columns /*, options*/) {
        var vals = [];
        columns.forEach((col) {
          vals.add(col.data);
        });

        vals = _flatten(vals);

        // save types and type options to later coerce
        var type = columns[0].type;

        // convert the values to their appropriate numeric value
        vals = vals.map((v) {
          return types[type].numeric(v);
        });
        return _mean(vals);
      });
}
