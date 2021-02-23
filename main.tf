locals {
   statements = flatten([
     for statement in jsondecode(data.aws_iam_policy.source.policy).Statement : {
         Sid = lookup(statement, "Sid", "${index(jsondecode(data.aws_iam_policy.source.policy).Statement,statement)}")
         Effect = statement.Effect
         Resource = try([tostring(statement.Resource)],tolist(statement.Resource))
         NotAction = lookup(statement, "NotAction", "")
         Action = lookup(statement, "Action", "")
         Condition = flatten([
           for k, v in lookup(statement, "Condition", {}) : [
	      for k2, v2 in v : {
		 Test =  k
		 Variable = k2
		 Values = try([tostring(v2)],tolist(v2))
               }
	     ]
         ])
      }
  ])
}

data "aws_iam_policy" "source" {
  arn = var.override_policy_source
}

data "aws_iam_policy_document" "source_plus_sid" {
  dynamic "statement" {
    for_each = local.statements
    
    content {
       sid = statement.value["Sid"]
       effect = statement.value["Effect"]
       resources = statement.value["Resource"]
       not_actions = statement.value["NotAction"] == "" ? null : try([tostring(statement.value["NotAction"])],tolist(statement.value["NotAction"]))
       actions = statement.value["Action"] == "" ? null : try([tostring(statement.value["Action"])],tolist(statement.value["Action"]))
       
       dynamic "condition" {
	  for_each = statement.value["Condition"]
	     
	    content {
	       test = condition.value["Test"]
	       variable = condition.value["Variable"]
	       values = condition.value["Values"]
            }
       }
     }
  }  
}

data "aws_iam_policy_document" "override_source" {
  source_json = data.aws_iam_policy_document.source_plus_sid.json
  
  statement {
    sid = var.override_policy_sid
    effect = var.override_policy_effect
    not_actions = var.override_policy_notactions == "" ? null : var.override_policy_notactions
    actions = var.override_policy_actions == "" ? null : var.override_policy_actions
    resources = var.override_policy_resources

    dynamic "condition" {
       for_each = var.override_policy_conditions
	    
        content {
	       test = condition.value["test"]
	       variable = condition.value["variable"]
	       values = condition.value["values"]
        }
    }
  }
}
