 output "merged_policy" {
  value =  data.aws_iam_policy_document.override_source.json
 }
