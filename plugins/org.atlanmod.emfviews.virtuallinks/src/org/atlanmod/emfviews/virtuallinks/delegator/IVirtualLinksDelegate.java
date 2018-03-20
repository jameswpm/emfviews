/*******************************************************************************
 * Copyright (c) 2018 Armines
 * Copyright (c) 2013 INRIA
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *
 * Contributors:
 *   fmdkdd - refactoring and extension
 *   Juan David Villa Calle - initial API and implementation
 *******************************************************************************/

package org.atlanmod.emfviews.virtuallinks.delegator;

import java.util.List;

import org.atlanmod.emfviews.virtuallinks.WeavingModel;
import org.eclipse.emf.common.util.URI;
import org.eclipse.emf.ecore.resource.Resource;

public interface IVirtualLinksDelegate {

  public WeavingModel createWeavingModel(URI linksDslFile, List<Resource> inputModels) throws Exception;

}