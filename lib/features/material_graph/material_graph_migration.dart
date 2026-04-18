import '../graph/models/graph_models.dart';

class MaterialGraphMigration {
  static const Map<String, Map<String, String>> _legacyKeyAliases = {
    'solid_color_node': {'output': '_output'},
    'mix_node': {
      'foreground': 'Foreground',
      'background': 'Background',
      'mask': 'Mask',
      'output': '_output',
    },
    'channel_select_node': {
      'channelRed': 'channel_red',
      'channelGreen': 'channel_green',
      'channelBlue': 'channel_blue',
      'channelAlpha': 'channel_alpha',
      'output': '_output',
    },
    'circle_node': {'output': '_output'},
    'curve_demo_node': {'output': '_output'},
  };

  static GraphDocument normalize(GraphDocument graph) {
    var didChange = false;
    final updatedNodes = graph.nodes
        .map((node) {
          final aliases = _legacyKeyAliases[node.definitionId];
          if (aliases == null || aliases.isEmpty) {
            return node;
          }

          var nodeChanged = false;
          final updatedProperties = node.properties
              .map((property) {
                final nextKey = aliases[property.definitionKey];
                if (nextKey == null || nextKey == property.definitionKey) {
                  return property;
                }

                nodeChanged = true;
                return property.copyWith(definitionKey: nextKey);
              })
              .toList(growable: false);

          if (!nodeChanged) {
            return node;
          }

          didChange = true;
          return node.copyWith(properties: updatedProperties);
        })
        .toList(growable: false);

    if (!didChange) {
      return graph;
    }

    return graph.copyWith(nodes: updatedNodes);
  }
}
