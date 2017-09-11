node('buildnode1'){
    stage('OM_LITE_Compile') {
        echo 'Start OM_LITE_Compile'
        build job: 'OM_LITE_Compile'
        echo 'End OM_LITE_Compile'
    }
    stage('OM_LITE_Pack') {
        echo 'Start OM_LITE_Pack'
        build job: 'OM_LITE_Pack'
        echo 'End OM_LITE_Pack'
    }
    stage('OM_LITE_Deploy_gamma') {
        echo 'Start OM_LITE_Deploy'
        println "inDeployIp is: ${params.inDeployIp}"
        build job: 'OM_LITE_Deploy'
        parameters: [
            string(name: 'inDeployIp', value: "${params.inDeployIp}"),
            string(name: 'omCore1_vip', value: "${params.omCore1_vip}"),
            string(name: 'omCore2_ip', value: "${params.omCore2_ip}"),
            string(name: 'omCore3_ip', value: "${params.omCore3_ip}"),
        ]
        echo 'End OM_LITE_Deploy'
    }
    stage('OM_LITE_Upload') {
        echo 'Start OM_LITE_Upload'
        build job: 'OM_LITE_Upload'
        echo 'End OM_LITE_Upload'
    }
}
