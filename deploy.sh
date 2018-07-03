#!/usr/bin/env bash

# more bash-friendly output for jq
JQ="jq --raw-output --exit-status"

configure_aws_cli(){
	aws --version
	aws configure set default.region us-east-1
	aws configure set default.output json
}

deploy_cluster() {

    family="Run-Githubot"

    make_task_def
    register_definition
    if [[ $(aws ecs update-service --cluster BotCluster --service bots --task-definition $revision | \
                   $JQ '.service.taskDefinition') != $revision ]]; then
        echo "Error updating service."
        return 1
    fi

    # wait for older revisions to disappear
    # not really necessary, but nice for demos
    for attempt in {1..40}; do
        if stale=$(aws ecs describe-services --cluster BotCluster --services bots | \
                       $JQ ".services[0].deployments | .[] | select(.taskDefinition != \"$revision\") | .taskDefinition"); then
            echo "Waiting for stale deployments:"
            echo "$stale"
            sleep 5
        else
            echo "Deployed!"
            return 0
        fi
    done
    echo "Service update took too long."
    return 1
}

make_task_def(){
	task_template='[
		{
			"name": "Run-Githubot",
			"image": "<image_id>",
			"essential": true,
			"memory": 512,
			"cpu": 256,
			"portMappings": [
        {
            "containerPort": 8080,
            "hostPort": 8080
        }
      ]
		}
	]'

	task_def=$(printf "$task_template")
}

push_ecr_image(){
	eval $(aws ecr get-login --no-include-email --region us-east-1)
	docker tag whobot:v_$CIRCLE_BUILD_NUM <image_id>
	docker push <image_id>
}

register_definition() {

    if revision=$(aws ecs register-task-definition --container-definitions "$task_def" --requires-compatibilities FARGATE --network-mode awsvpc --cpu 256 --memory 512 --execution-role-arn <arn_id> --family $family | $JQ '.taskDefinition.taskDefinitionArn'); then
        echo "Revision: $revision"
    else
        echo "Failed to register task definition"
        return 1
    fi

}

configure_aws_cli
push_ecr_image
deploy_cluster
