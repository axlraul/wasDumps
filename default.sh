SCRIPTNAME="wasDumps"
fileSystem="/logs/apps/websphere85/dumps"
path="/logs/apps/websphere85/dumps/"
auxPath="/tmp"
#
#-------


totalUsado=$(df -Th | grep -i $fileSystem | awk '{print $3}')
totalDisp=$(df -Th | grep -i $fileSystem | awk '{print $4}')
totalFS=$(df -Th | grep -i $fileSystem | awk '{print $2}')
totalPUsado=$(df -Th | grep -i $fileSystem | awk '{print $5}')
lastJavacore=$(ls -rt $path | grep javacore | tail -1)
lastSnap=$(ls -rt $path | grep Snap | tail -1)
lastHeapdump=$(ls -rt $path |  grep heapdump | tail -1)

#echo "$lastHeapdump"
#echo "$lastSnap"
#echo "$lastJavacore"
mapfile -t oldFilesToDelete < <(ls -p $path | grep -Ev "$lastJavacore|$lastSnap|$lastHeapdump" )

#  for i in ${oldFilesToDelete[@]}; do
#          echo "$i"
#        done



echo -e "\n\nTamaño actual ocupado: $totalUsado - $totalPUsado de un total de $totalFS. Total disponible $totalDisp"
sleep 1

echo -e "\nLiberar espacio en $path? [ si | no ] " && read -r PROCRPT
echo -e "\n\n"

if [ -z "$PROCRPT" ]; then echo "No se ha especificado opcion. Saliendo del script" && exit 1; fi
  case "$PROCRPT" in
    si|s )
      echo -e "1 - Borrando archivos antiguos"
      echo -e "---> Realizando operacion borrado"
      if [ -z "$oldFilesToDelete" ]; then
        echo -e "\tEspacio liberado anteriormente"
      else
        for i in ${oldFilesToDelete[@]}; do
          echo -ne "\tEliminando $i"
          rm -f $path$i
          echo -e "  OK"
        done
      fi
      echo -e "\n2 - Compresion / Truncado de ultimos archivos en uso"
      echo -e "---> Realizando compresion/truncado"
      for i in $lastJavacore $lastSnap $lastHeapdump ; do \
        if [ ${i: -3} == ".gz" ]; then
          echo -e "\tArchivo $i comprimido anteriormente"
        else
          FILE_IN_USE="$(lsof +D $path | grep $i | awk '{print $9}')"

          if [ -z "$FILE_IN_USE" ]; then
            echo -ne "\tComprimiendo $i"
            gzip -9 $path$i && echo -e "  OK"
          else

            totalDispAux=$(df -k | grep -i $auxPath | awk '{print $3}')
            fileSize=$(ls -l $path$i | awk '{print $5}')
#           echo "totalDispAux= $totalDispAux"
#           echo "fileSize= $fileSize"
            if [ $totalDispAux -le $fileSize ]; then
              echo -e "\tNo es posible truncar $i. Espacio disp: $totalDispAux B. Espacio necesario: $fileSize B"
            else
              echo -e "\tEs necesario truncar $i"

#              if ls $path$i*.????????.??????.????.????.???.gz 1> /dev/null 2>&1; then
#                rm -Rf $path$i.????????.??????.????.????.???*gz
#              fi

              echo -ne "\t  Copiando $i a directorio auxiliar $auxPath"
              cp -p $path$i $auxPath/$i && echo -e "  OK"

              echo -ne "\t  Truncando $i"
              echo -n > $path$i && echo -e "  OK"

              echo -ne "\t  Comprimiendo el archivo copiado recientemente"
              gzip -9 $auxPath/$i && echo -e "  OK"

              echo -ne "\t  Retornando el archivo truncado a su ubicacion original"
              mv "$auxPath/$i.gz" "$path$i$(date +"_%d-%m-%y-%H-%M-%S").gz" && echo -e "  OK"

              echo -e "\tOperacion de truncado realizada correctamente\n"
            fi
          fi
        fi
      done
      ;;

    no|n )
      echo -e "Saliendo"
      ;;

    * )
      echo -e "Opcion incorrecta. No se realizara ninguna accion."
      ;;
  esac
echo -e "\n\n\tEspacio liberado correctamente"

totalUsado=$(df -Th | grep -i $fileSystem | awk '{print $3}')
totalDisp=$(df -Th | grep -i $fileSystem | awk '{print $4}')
totalFS=$(df -Th | grep -i $fileSystem | awk '{print $2}')
totalPUsado=$(df -Th | grep -i $fileSystem | awk '{print $5}')

echo -e "\n\nTamaño actual ocupado: "$totalUsado " - " $totalPUsado " de un total de "$totalFS". Total disponible "$totalDisp""
