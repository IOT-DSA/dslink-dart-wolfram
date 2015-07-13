import "dart:convert";

import "package:dslink/dslink.dart";
import "package:dslink/nodes.dart";

import "package:http/http.dart" as http;

http.Client client = new http.Client();

LinkProvider link;

main(List<String> args) async {
  link = new LinkProvider(args, "Wolfram-", defaultNodes: {
    "Add_Account": {
      r"$name": "Add Account",
      r"$is": "addAccount",
      r"$result": "value",
      r"$invokable": "write",
      r"$params": [
        {
          "name": "name",
          "type": "string"
        },
        {
          "name": "appid",
          "type": "string"
        }
      ]
    }
  },
  profiles: {
    "addAccount": (String path) => new SimpleActionNode(path, (Map<String, dynamic> params) async {
      var name = params["name"];
      var appid = params["appid"];
      var rname = name.replaceAll(" ", "_").replaceAll("'", "_");
      link.addNode("/${name}", {
        r"$name": name,
        r"$is": "account",
        r"$$wolfram_appid": appid
      });
      await link.saveAsync();
    }),
    "account": (String path) => new AccountNode(path),
    "query": (String path) => new SimpleActionNode(path, (Map<String, dynamic> params) async {
      try {
        var appid = (link[new Path(path).parentPath] as AccountNode).appId;
        var input = Uri.encodeComponent(params["input"]);
        var url = "http://api.wolframalpha.com/v2/query?appid=${appid}&input=${input}&format=plaintext&output=json";
        var json = JSON.decode((await client.get(url)).body);
        var qr = json["queryresult"];
        var data = [];
        for (var pod in qr["pods"]) {
          data.add({
            "pod": pod["title"],
            "position": pod["position"],
            "text": pod["subpods"].first["plaintext"]
          });
        }
        return data;
      } catch (e) {
        print(e);
        return [];
      }
    })
  }, autoInitialize: false);

  link.init();
  link.connect();
}

final Map<String, dynamic> ACCOUNT_CHILDREN = {
  "Query": {
    r"$result": "table",
    r"$is": "query",
    r"$invokable": "read",
    r"$params": [
      {
        "name": "input",
        "type": "string"
      }
    ],
    r"$columns": [
      {
        "name": "pod",
        "type": "string"
      },
      {
        "name": "position",
        "type": "number"
      },
      {
        "name": "text",
        "type": "string"
      }
    ]
  }
};

class AccountNode extends SimpleNode {
  String get appId => configs[r"$$wolfram_appid"];

  AccountNode(String path) : super(path, link.provider) {
    Scheduler.later(() {
      for (var m in ACCOUNT_CHILDREN.keys) {
        link.addNode("${path}/${m}", ACCOUNT_CHILDREN[m]);
        SimpleNode node = link["${path}/${m}"];
        node.serializable = false;
      }
    });
  }
}
