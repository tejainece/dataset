(function(global, _) {

  var Dataset = global.Miso.Dataset;

  /**
   * Handles basic strict data format. Looks like:
   *
   *     {
   *       data : {
   *         columns : [
   *           { name : colName, type : colType, data : [...] }
   *         ]
   *       }
   *     }
   *
   * @constructor
   * @name Strict
   * @memberof Miso.Dataset.Parsers
   * @augments Miso.Dataset.Parsers
   *
   * @param {Object} [options]
   */
  Dataset.Parsers.Strict = function( options ) {
    this.options = options || {};
  }; 

  _.extend( Dataset.Parsers.Strict.prototype, Dataset.Parsers.prototype, {

    parse : function( data ) {
      var columnData = {}, columnNames = [];

      _.each(data.columns, function(column) {
        if (columnNames.indexOf(column.name) !== -1) {
          throw new Error("You have more than one column named \"" + column.name + "\"");
        } else {
          columnNames.push( column.name );
          columnData[ column.name ] = column.data;  
        }
      });

      return {
        columns : columnNames,
        data : columnData 
      };
    }

  });

}(this, _));
