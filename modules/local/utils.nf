/*
 * ========================================
 *  UTILITIES - Helper processes
 * ========================================
 */

process CUSTOM_DUMPSOFTWAREVERSIONS {
    tag "versions"
    label 'process_single'
    
    conda "bioconda::multiqc=1.21"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/multiqc:1.21--pyhdfd78af_0' :
        'quay.io/biocontainers/multiqc:1.21--pyhdfd78af_0' }"
    
    input:
    path versions
    
    output:
    path "software_versions.yml"    , emit: yml
    path "software_versions_mqc.yml", emit: mqc_yml
    path "versions.yml"             , emit: versions
    
    when:
    task.ext.when == null || task.ext.when
    
    script:
    """
    # Collect all version files
    for file in ${versions}; do
        cat \$file >> all_versions.yml
    done
    
    # Create formatted version files
    cat <<-END_YML > software_versions.yml
    "WES/WGS DeepVariant Pipeline":
        nextflow: ${workflow.nextflow.version}
        date: ${new java.util.Date().format('yyyy-MM-dd')}
    END_YML
    
    # Append tool versions
    cat all_versions.yml >> software_versions.yml
    
    # Create MultiQC-compatible version file
    cat <<-END_MQC > software_versions_mqc.yml
    id: 'software_versions'
    section_name: 'WES/WGS DeepVariant Pipeline Software Versions'
    section_href: 'https://github.com'
    plot_type: 'html'
    description: 'Software versions used in the pipeline'
    data: |
        <dl class="dl-horizontal">
    END_MQC
    
    # Parse versions for MultiQC
    while IFS= read -r line; do
        if [[ \$line == *":"* ]]; then
            tool=\$(echo \$line | cut -d':' -f1 | tr -d ' "')
            version=\$(echo \$line | cut -d':' -f2 | tr -d ' "')
            if [[ \$tool && \$version ]]; then
                echo "        <dt>\${tool}</dt><dd>\${version}</dd>" >> software_versions_mqc.yml
            fi
        fi
    done < software_versions.yml
    
    echo "        </dl>" >> software_versions_mqc.yml
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //')
    END_VERSIONS
    """
}
