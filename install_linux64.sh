#!/bin/bash

## Adapted from code by Nadia Davidson: https://github.com/Oshlack/JAFFA/blob/master/install_linux64.sh
## This script installs the prerequisite software for the MINTIE pipeline
## It will fetch each tool from the web and place it into the tools/ subdirectory.
## Paths to all installed tools can be found in the file tools.groovy at the
## end of execution of this script. These paths can be changed if a different
## version of software is required. Note that R must be installed manually

mkdir -p tools/bin
cd tools

#a list of which programs need to be installed
commands="bpipe fastuniq dedupe trimmomatic fasta_formatter samtools bedtools soapdenovotrans salmon hisat gmap"

#installation methods
function bpipe_install {
    wget -O bpipe-0.9.9.5.tar.gz https://github.com/ssadedin/bpipe/releases/download/0.9.9.5/bpipe-0.9.9.5.tar.gz
    tar -zxvf bpipe-0.9.9.5.tar.gz ; rm bpipe-0.9.9.5.tar.gz
    ln -s $PWD/bpipe-0.9.9.5/bin/* $PWD/bin/
}

function fastuniq_install {
    wget --no-check-certificate https://sourceforge.net/projects/fastuniq/files/FastUniq-1.1.tar.gz
    tar -xvzf FastUniq-1.1.tar.gz
    rm FastUniq-1.1.tar.gz
    make -C FastUniq/source/
    ln -s $PWD/FastUniq/source/fastuniq $PWD/bin
}

function trimmomatic_install {
    wget http://www.usadellab.org/cms/uploads/supplementary/Trimmomatic/Trimmomatic-0.39.zip
    unzip Trimmomatic-0.39.zip ; rm Trimmomatic-0.39.zip
    echo "java -jar $PWD/Trimmomatic-0.39/trimmomatic-0.39.jar \$*"  > Trimmomatic-0.39/trimmomatic.sh
    chmod +x Trimmomatic-0.39/trimmomatic.sh
    ln -s $PWD/Trimmomatic-0.39/trimmomatic.sh $PWD/bin/trimmomatic
}

function soapdenovotrans_install {
    wget --no-check-certificate https://github.com/aquaskyline/SOAPdenovo-Trans/archive/1.0.4.tar.gz
    tar -xvzf 1.0.4.tar.gz
    rm 1.0.4.tar.gz
    cd SOAPdenovo-Trans-1.0.4
    chmod u+x make.sh && ./make.sh ; cd ..
    ln -s $PWD/SOAPdenovo-Trans-1.0.4/SOAPdenovo-Trans-127mer $PWD/bin/soapdenovotrans
}

function fasta_formatter_install {
    wget http://hannonlab.cshl.edu/fastx_toolkit/fastx_toolkit_0.0.13_binaries_Linux_2.6_amd64.tar.bz2
    tar -jxvf fastx_toolkit_0.0.13_binaries_Linux_2.6_amd64.tar.bz2
    rm fastx_toolkit_0.0.13_binaries_Linux_2.6_amd64.tar.bz2
}

function dedupe_install {
    wget --no-check-certificate https://sourceforge.net/projects/bbmap/files/BBMap_38.50b.tar.gz
    tar -zxvf BBMap_38.50b.tar.gz
    rm BBMap_38.50b.tar.gz
    for script in `ls $PWD/bbmap/*.sh` ; do
        s=`basename $script`
        s_pre=`echo $s | sed 's/.sh//g'`
        echo "$PWD/bbmap/$s \$@" > $PWD/bin/$s_pre
        chmod +x $PWD/bin/$s_pre
    done
}

function samtools_install {
    wget --no-check-certificate http://sourceforge.net/projects/samtools/files/samtools/1.9/samtools-1.9.tar.bz2
    tar -jxvf samtools-1.9.tar.bz2
    rm samtools-1.9.tar.bz2
    make prefix=$PWD install -C samtools-1.9/
}

function bedtools_install {
    wget --no-check-certificate https://github.com/arq5x/bedtools2/releases/download/v2.28.0/bedtools
    chmod u+x $PWD/bedtools
    ln -s $PWD/bedtools $PWD/bin
}

function gmap_install {
    wget --no-check-certificate http://research-pub.gene.com/gmap/src/gmap-gsnap-2019-05-12.tar.gz
    tar -xvzf gmap-gsnap-2019-05-12.tar.gz
    rm gmap-gsnap-2019-05-12.tar.gz
    cd gmap-2019-05-12 && ./configure --prefix=$PWD/../ ; cd ..
    make -C gmap-2019-05-12/
    make prefix=$PWD install -C gmap-2019-05-12/
}

function salmon_install {
    wget --no-check-certificate https://github.com/COMBINE-lab/salmon/releases/download/v0.14.0/salmon-0.14.0_linux_x86_64.tar.gz
    tar -xvzf salmon-0.14.0_linux_x86_64.tar.gz
    rm salmon-0.14.0_linux_x86_64.tar.gz
    ln -s $PWD/salmon-latest_linux_x86_64/bin/salmon $PWD/bin
}

function hisat_install {
    wget --no-check-certificate http://ccb.jhu.edu/software/hisat2/dl/hisat2-2.1.0-Linux_x86_64.zip
    unzip hisat2-2.1.0-Linux_x86_64.zip
    rm hisat2-2.1.0-Linux_x86_64.zip
    ln -s $PWD/hisat2-2.1.0/hisat2 $PWD/bin/hisat
    ln -s $PWD/hisat2-2.1.0/hisat2-build $PWD/bin/hisat-build
}

echo "// Path to tools used by the MINTIE pipeline" > ../tools.groovy

for c in $commands ; do
    c_path=`which $PWD/bin/$c 2>/dev/null`
    if [ -z $c_path ] ; then
    echo "$c not found, fetching it"
    ${c}_install
    c_path=`which $PWD/bin/$c 2>/dev/null`
    fi
    echo "$c=\"$c_path\"" >> ../tools.groovy
done

# check that R is installed
R_path=`which R 2>/dev/null`
if [ -z $R_path ] ; then
    echo "R not found!"
    echo "Please go to http://www.r-project.org/ and follow the installation instructions."
    echo "Note that data.table, dplyr and seqinr must be installed."
fi
echo "R=\"$R_path\"" >> ../tools.groovy

# check that python is installed
# install requirements if so
python_path=`which python 2>/dev/null`
if [ -z $python_path ] ; then
    echo "Python not found!"
    echo "Please go to https://www.anaconda.com/distribution/#download-section,"
    echo "download the Python 3.7+ version and follow download instructions."
    echo "Then install requirements by running \"pip install -r requirements.txt\""
else
    echo "Installing python requirements..."
    pip install -r ../requirements.txt
fi
echo "python=\"$python_path\"" >> ../tools.groovy

#loop through commands to check they are all installed
echo "Checking that all required tools were installed:"
Final_message="All commands installed successfully!"
for c in $commands ; do
    c_path=`which $PWD/bin/$c 2>/dev/null`
    if [ -z $c_path ] ; then
    echo -n "WARNING: $c could not be found!!!! "
    echo "You will need to download and install $c manually, then add its path to tools.groovy"
    Final_message="WARNING: One or more command did not install successfully. See warning messages above. \
                       You will need to correct this before running MINTIE."
    else
        echo "$c looks like it has been installed"
    fi
done
echo "**********************************************************"
echo $Final_message